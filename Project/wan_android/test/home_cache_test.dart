// 测试首页的"离线缓存兜底"：网络成功 → 写缓存；网络失败 → 读缓存降级；
// 网络失败且没缓存 → 维持错误态。
// 依然是 ProviderContainer + fake repository（呼应 widget_test 的 override 手法）。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wan_android/core/error/failure.dart';
import 'package:wan_android/features/products/data/product_list_response.dart';
import 'package:wan_android/features/products/data/products_cache.dart';
import 'package:wan_android/features/products/data/products_repository.dart';
import 'package:wan_android/features/products/domain/product.dart';
import 'package:wan_android/features/products/presentation/providers/products_providers.dart';

Product _makeProduct(int id) => Product(
  id: id,
  title: 'product-$id',
  description: 'desc',
  category: 'test',
  price: 100,
  discountPercentage: 0,
  rating: 4.5,
  stock: 10,
  thumbnail: 'http://x/$id.png',
  images: const [],
  tags: null,
);

/// 网络正常的假仓库：固定返回两个商品。
class _OkRepository extends ProductsRepository {
  @override
  Future<ProductListResponse> fetchProducts({int limit = 20, int skip = 0}) async {
    final products = [_makeProduct(1), _makeProduct(2)];
    return ProductListResponse(
      products: products,
      total: products.length,
      skip: skip,
      limit: limit,
    );
  }
}

/// 断网的假仓库：一调就抛 NetworkException（≈ 飞行模式）。
class _OfflineRepository extends ProductsRepository {
  @override
  Future<ProductListResponse> fetchProducts({int limit = 20, int skip = 0}) {
    throw const NetworkException('无法连接服务器，请检查网络');
  }
}

ProviderContainer _makeContainer(ProductsRepository repo) {
  return ProviderContainer(
    // Riverpod 3 的新默认行为：provider 的 build 抛错后会**自动按指数退避重试**，
    // 重试期间 .future 一直悬而不决——对真实 App 是贴心兜底，对测试是"卡 30 秒超时"。
    // 测试要确定性：返回 null = 不重试，让错误立刻定格。
    retry: (retryCount, error) => null,
    overrides: [productsRepositoryProvider.overrideWithValue(repo)],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('网络成功：正常返回数据，且顺手写入了缓存', () async {
    final container = _makeContainer(_OkRepository());
    addTearDown(container.dispose);

    final products = await container.read(productListProvider.future);
    expect(products, hasLength(2));
    expect(container.read(productListProvider.notifier).isFromCache, isFalse);

    // build() 里的 cache.save 是不 await 的后台副作用，
    // 等一个事件循环让它跑完（≈ XCTest 里等一拍再断言异步副作用）。
    await Future<void>.delayed(Duration.zero);
    final cached = await ProductsCache().load();
    expect(cached, isNotNull);
    expect(cached, hasLength(2));
  });

  test('网络失败但有缓存：降级返回缓存数据，isFromCache=true、不再分页', () async {
    // 先手动种一份缓存（模拟"上次联网时存下的"）。
    await ProductsCache().save([_makeProduct(9)]);

    final container = _makeContainer(_OfflineRepository());
    addTearDown(container.dispose);

    final products = await container.read(productListProvider.future);
    expect(products, hasLength(1));
    expect(products.first.id, 9);

    final notifier = container.read(productListProvider.notifier);
    expect(notifier.isFromCache, isTrue);
    expect(notifier.hasMore, isFalse); // 离线数据不该再触发上拉加载
  });

  test('网络失败且无缓存：错误照常抛出（页面仍走 error 态）', () async {
    final container = _makeContainer(_OfflineRepository());
    addTearDown(container.dispose);

    // productListProvider 是 autoDispose 的（对比 cart/favorites 的 keepAlive）：
    // 测试里只 read 不 listen 的话，没有任何"订阅者"，provider 会在 loading 中途
    // 就被回收，错误还没抛出来 future 先报 disposed——M7 教训 2 在测试里的重演。
    // 真实 App 里首页一直 watch 着它所以没事；测试里要自己挂一个监听保活。
    final sub = container.listen(productListProvider, (_, _) {});
    addTearDown(sub.close);

    await expectLater(
      container.read(productListProvider.future),
      throwsA(isA<NetworkException>()),
    );
  });
}
