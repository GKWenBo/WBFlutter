import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/api/product_api.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v4_riverpod/state/api_provider.dart';
import 'package:state_lab/versions/v4_riverpod/state/product_list_notifier.dart';

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
  group('ProductListNotifier', () {
    late _PagedFakeApi api;
    late ProviderContainer container;
    late ProviderSubscription<AsyncValue<ProductListData>> sub;

    setUp(() {
      api = _PagedFakeApi();
      // override 注入假 API——和 V4ShopRoot 生产注入走同一个口子。
      // retry: null 关掉 riverpod 3 的自动重试（默认 build 失败会按退避
      // 策略自动重跑——failNext 只坏一次，不关重试 AsyncError 根本抓不到）
      container = ProviderContainer(
        overrides: [productApiProvider.overrideWithValue(api)],
        retry: (retryCount, error) => null,
      );
      // autoDispose：没人监听就地销毁，测试里挂个监听保活（= 页面在场）
      sub = container.listen(productListProvider, (_, _) {});
      addTearDown(container.dispose);
    });

    test('build 即首载：AsyncLoading → AsyncData 第一页', () async {
      // 用测试内新建的 container：listen 到断言之间无 await 边界，
      // 保证抓到首帧 AsyncLoading（三态由 AsyncValue 内建）
      final fresh = ProviderContainer(
        overrides: [productApiProvider.overrideWithValue(_PagedFakeApi())],
      );
      addTearDown(fresh.dispose);
      fresh.listen(productListProvider, (_, _) {});
      expect(fresh.read(productListProvider), isA<AsyncLoading<ProductListData>>());
      final data = await fresh.read(productListProvider.future);
      expect(data.items.length, 2);
      expect(data.hasMore, isTrue);
    });

    test('loadMore：翻页追加，到底后 hasMore=false；不再发请求', () async {
      await container.read(productListProvider.future);
      await container.read(productListProvider.notifier).loadMore();
      final data = container.read(productListProvider).requireValue;
      expect(data.items.length, 3);
      expect(data.hasMore, isFalse);
      final calls = api.fetchCalls;
      await container.read(productListProvider.notifier).loadMore();
      expect(api.fetchCalls, calls);
    });

    test('刷新失败：AsyncError（三态是类型，不是自维护字段）', () async {
      await container.read(productListProvider.future); // 首载成功落地
      api.failNext = true;
      // refresh = invalidate + 返回新一轮 build 的 future（RefreshIndicator 同款）
      await expectLater(
        container.refresh(productListProvider.future),
        throwsException,
      );
      expect(container.read(productListProvider), isA<AsyncError<ProductListData>>());
    });

    test('loadMore 失败不打断已有列表（静默语义与 v0–v3 一致）', () async {
      await container.read(productListProvider.future);
      api.failNext = true;
      await container.read(productListProvider.notifier).loadMore();
      final data = container.read(productListProvider).requireValue;
      expect(data.items.length, 2); // 旧数据还在，没掉进 AsyncError
      expect(data.hasMore, isTrue);
      expect(data.loadingMore, isFalse);
    });

    test('autoDispose：最后一个监听者离场，provider 销毁重建', () async {
      await container.read(productListProvider.future);
      final callsBefore = api.fetchCalls;
      sub.close(); // "页面 pop"
      await Future<void>.delayed(Duration.zero); // 销毁在微任务后生效
      container.listen(productListProvider, (_, _) {}); // "重新进页"
      await container.read(productListProvider.future);
      expect(api.fetchCalls, callsBefore + 1); // 重建重载了
    });
  });
}
