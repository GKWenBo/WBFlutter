import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/api/product_api.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v3_getx/state/product_list_getx_controller.dart';

const _p1 = Product(id: 1, title: 'A', description: 'a', price: 1, thumbnail: 'x', rating: 4);
const _p2 = Product(id: 2, title: 'B', description: 'b', price: 2, thumbnail: 'x', rating: 4);
const _p3 = Product(id: 3, title: 'C', description: 'c', price: 3, thumbnail: 'x', rating: 4);

/// 假 API：3 条数据、每页 2 条；可指定"下一次调用抛错"。
class _PagedFakeApi implements ProductApi {
  bool failNext = false;
  int fetchCalls = 0;

  @override
  Future<ProductPage> fetchProducts({
    required int skip,
    int limit = ProductApi.pageSize,
  }) async {
    fetchCalls++;
    if (failNext) {
      failNext = false;
      throw Exception('网络挂了');
    }
    const all = [_p1, _p2, _p3];
    final slice = all.skip(skip).take(2).toList();
    return ProductPage(products: slice, total: all.length, skip: skip, limit: limit);
  }

  @override
  Future<List<Product>> searchProducts(String query) => throw UnimplementedError();
}

void main() {
  group('ProductListGetxController（手动挡）', () {
    test('loadFirst：落地第一页', () async {
      final c = ProductListGetxController(_PagedFakeApi());
      await c.loadFirst();
      expect(c.items.length, 2);
      expect(c.hasMore, isTrue);
      expect(c.loading, isFalse);
      expect(c.error, isNull);
    });

    test('loadMore：翻页追加，到底后 hasMore=false；不再发请求', () async {
      final api = _PagedFakeApi();
      final c = ProductListGetxController(api);
      await c.loadFirst();
      await c.loadMore();
      expect(c.items.length, 3);
      expect(c.hasMore, isFalse);
      final calls = api.fetchCalls;
      await c.loadMore();
      expect(api.fetchCalls, calls);
    });

    test('loadFirst 失败：error 落地；重试成功后清 error', () async {
      final api = _PagedFakeApi()..failNext = true;
      final c = ProductListGetxController(api);
      await c.loadFirst();
      expect(c.error, contains('加载失败'));
      expect(c.items, isEmpty);
      await c.loadFirst();
      expect(c.error, isNull);
      expect(c.items.length, 2);
    });

    test('loadMore 失败不打断已有列表（静默语义与 v0/v1/v2 一致）', () async {
      final api = _PagedFakeApi();
      final c = ProductListGetxController(api);
      await c.loadFirst();
      api.failNext = true;
      await c.loadMore();
      expect(c.items.length, 2); // 旧数据还在
      expect(c.error, isNull);
      expect(c.hasMore, isTrue); // 还能再试
    });

    test('update(ids) 定向刷新：loadMore 的 loadingMore 翻转只惊动 footer', () async {
      final c = ProductListGetxController(_PagedFakeApi());
      var listFired = 0;
      var footerFired = 0;
      c.addListenerId('list', () => listFired++);
      c.addListenerId('footer', () => footerFired++);

      await c.loadFirst(); // 开始+结束各刷一次 ['list','footer']
      expect(listFired, 2);
      expect(footerFired, 2);

      await c.loadMore(); // 开始只刷 ['footer']，结束刷 ['list','footer']
      expect(listFired, 3, reason: 'list 只在数据落地时刷一次');
      expect(footerFired, 4, reason: 'footer 开始/结束各一次');
    });
  });
}
