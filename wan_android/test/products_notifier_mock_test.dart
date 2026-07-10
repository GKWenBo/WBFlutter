// M11 教学重点：用 mocktail 取代"手写 fake 类"。
//
// 对照 test/home_cache_test.dart（手写 _OkRepository/_OfflineRepository）：
//   手写 fake 的短板是——每种返回值都要新写一个类，而且**无法验证"谁调了它、
//   调了几次、传了什么参数"**。mocktail 一行 `when(...).thenAnswer(...)` 就能定制返回，
//   再用 `verify(...).called(n)` 反过来检查交互。
//
// iOS 对照：≈ 你手写 mock 对象或用 OCMock/Cuckoo——
//   `when` ≈ stub 返回值，`verify` ≈ `OCMVerify` / XCTest 里数调用次数。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wan_android/core/error/failure.dart';
import 'package:wan_android/features/products/data/product_list_response.dart';
import 'package:wan_android/features/products/data/products_repository.dart';
import 'package:wan_android/features/products/domain/product.dart';
import 'package:wan_android/features/products/presentation/providers/products_providers.dart';

// 关键区别：mock 用 `implements` 而不是 `extends`。
// 它**不继承任何真实实现**——所有方法默认返回一个"哨兵值"，必须靠 when() 显式打桩，
// 没打桩就调用会抛错提醒你（这正是我们要的：测试里绝不该有未预期的真实网络调用）。
class MockProductsRepository extends Mock implements ProductsRepository {}

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

/// 造一页响应：[count] 条商品，[total] 决定 hasMore（total 大于已取到的就还有下一页）。
ProductListResponse _page({
  required int startId,
  required int count,
  required int skip,
  required int total,
}) => ProductListResponse(
  products: List.generate(count, (i) => _makeProduct(startId + i)),
  total: total,
  skip: skip,
  limit: 20,
);

/// 关掉 Riverpod 3 的自动重试（同 home_cache_test 的说明），让错误路径立刻定格。
ProviderContainer _containerWith(ProductsRepository repo) => ProviderContainer(
  retry: (retryCount, error) => null,
  overrides: [productsRepositoryProvider.overrideWithValue(repo)],
);

void main() {
  setUp(() {
    // Cache 会读 shared_preferences，给一份内存假实现。
    SharedPreferences.setMockInitialValues({});
  });

  test('首屏 build 用 skip:0 拉第一页——verify 证明确实调了这一次', () async {
    final repo = MockProductsRepository();
    // when + thenAnswer：给"参数匹配 skip:0"的调用打桩返回第一页。
    // any(named: 'limit') 表示 limit 传什么都行（我们只关心 skip）。
    when(
      () => repo.fetchProducts(limit: any(named: 'limit'), skip: 0),
    ).thenAnswer((_) async => _page(startId: 1, count: 20, skip: 0, total: 40));

    final container = _containerWith(repo);
    addTearDown(container.dispose);

    final products = await container.read(productListProvider.future);
    expect(products, hasLength(20));

    // verify：手写 fake 做不到的能力——断言"这个方法被以 skip:0 恰好调用了一次"。
    verify(() => repo.fetchProducts(limit: 20, skip: 0)).called(1);
    // 首屏还没上拉，不该出现 skip:20 的第二页请求。
    verifyNever(() => repo.fetchProducts(limit: 20, skip: 20));
  });

  test('loadMore 用 skip=已有条数 翻页，两页参数都能被 verify 精确验证', () async {
    final repo = MockProductsRepository();
    // 同一个方法按参数分别打桩：skip:0 给第一页，skip:20 给第二页。
    when(
      () => repo.fetchProducts(limit: any(named: 'limit'), skip: 0),
    ).thenAnswer((_) async => _page(startId: 1, count: 20, skip: 0, total: 40));
    when(
      () => repo.fetchProducts(limit: any(named: 'limit'), skip: 20),
    ).thenAnswer((_) async => _page(startId: 21, count: 20, skip: 20, total: 40));

    final container = _containerWith(repo);
    addTearDown(container.dispose);

    // 先等首屏好，再触发上拉。
    await container.read(productListProvider.future);
    await container.read(productListProvider.notifier).loadMore();

    final all = container.read(productListProvider).value;
    expect(all, hasLength(40)); // 两页拼起来
    expect(all!.last.id, 40);

    // 核心断言：翻页的 skip 必须是"已有条数"20，而不是写死的页码。
    verify(() => repo.fetchProducts(limit: 20, skip: 0)).called(1);
    verify(() => repo.fetchProducts(limit: 20, skip: 20)).called(1);
  });

  test('拉到最后一页后 hasMore=false，再调 loadMore 不会真的发请求（verifyNever）', () async {
    final repo = MockProductsRepository();
    // total=20 = 一页就取完 → hasMore 为 false。
    when(
      () => repo.fetchProducts(limit: any(named: 'limit'), skip: 0),
    ).thenAnswer((_) async => _page(startId: 1, count: 20, skip: 0, total: 20));

    final container = _containerWith(repo);
    addTearDown(container.dispose);

    await container.read(productListProvider.future);
    expect(container.read(productListProvider.notifier).hasMore, isFalse);

    // 已经没有更多，loadMore 应该被 `!_hasMore` 短路，绝不发第二次请求。
    await container.read(productListProvider.notifier).loadMore();
    verifyNever(() => repo.fetchProducts(limit: any(named: 'limit'), skip: 20));
  });

  test('网络抛错且无缓存：thenThrow 模拟断网，错误照常冒泡到 error 态', () async {
    final repo = MockProductsRepository();
    // thenThrow：给这次调用打桩成"抛异常"，模拟断网。
    when(
      () => repo.fetchProducts(limit: any(named: 'limit'), skip: any(named: 'skip')),
    ).thenThrow(const NetworkException('无法连接服务器'));

    final container = _containerWith(repo);
    addTearDown(container.dispose);

    // autoDispose provider 在 loading 中途会被回收，挂一个监听保活（同 home_cache_test）。
    final sub = container.listen(productListProvider, (_, _) {});
    addTearDown(sub.close);

    await expectLater(
      container.read(productListProvider.future),
      throwsA(isA<NetworkException>()),
    );
  });
}
