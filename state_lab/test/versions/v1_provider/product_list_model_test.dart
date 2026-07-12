import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/api/product_api.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v1_provider/state/product_list_model.dart';

const _p1 = Product(id: 1, title: 'A', description: 'a', price: 1,
    thumbnail: 'x', rating: 4);
const _p2 = Product(id: 2, title: 'B', description: 'b', price: 2,
    thumbnail: 'x', rating: 4);
const _p3 = Product(id: 3, title: 'C', description: 'c', price: 3,
    thumbnail: 'x', rating: 4);

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
    return ProductPage(
        products: slice, total: all.length, skip: skip, limit: limit);
  }

  @override
  Future<List<Product>> searchProducts(String query) =>
      throw UnimplementedError();
}

void main() {
  group('ProductListModel', () {
    test('loadFirst：loading 经历 true→false，落地第一页', () async {
      final model = ProductListModel(_PagedFakeApi());
      final loadingTrace = <bool>[];
      model.addListener(() => loadingTrace.add(model.loading));
      await model.loadFirst();
      expect(loadingTrace, [true, false]);
      expect(model.items.length, 2);
      expect(model.hasMore, isTrue);
      expect(model.error, isNull);
    });

    test('loadMore：翻页追加，到底后 hasMore=false', () async {
      final model = ProductListModel(_PagedFakeApi());
      await model.loadFirst();
      await model.loadMore();
      expect(model.items.length, 3);
      expect(model.hasMore, isFalse);
    });

    test('没有更多后 loadMore 不再发请求', () async {
      final api = _PagedFakeApi();
      final model = ProductListModel(api);
      await model.loadFirst();
      await model.loadMore();
      final calls = api.fetchCalls;
      await model.loadMore();
      expect(api.fetchCalls, calls);
    });

    test('loadFirst 失败：error 落地；重试成功后清 error', () async {
      final api = _PagedFakeApi()..failNext = true;
      final model = ProductListModel(api);
      await model.loadFirst();
      expect(model.error, contains('加载失败'));
      expect(model.items, isEmpty);
      await model.loadFirst();
      expect(model.error, isNull);
      expect(model.items.length, 2);
    });

    test('loadMore 失败不打断已有列表', () async {
      final api = _PagedFakeApi();
      final model = ProductListModel(api);
      await model.loadFirst();
      api.failNext = true;
      await model.loadMore();
      expect(model.items.length, 2); // 旧数据还在
      expect(model.error, isNull); // 静默失败，同 v0 语义
      expect(model.hasMore, isTrue); // 还能再试
    });
  });
}
