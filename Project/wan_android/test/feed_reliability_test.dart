import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wan_android/core/error/failure.dart';
import 'package:wan_android/features/products/data/product_list_response.dart';
import 'package:wan_android/features/products/data/products_cache.dart';
import 'package:wan_android/features/products/data/products_dependencies.dart';
import 'package:wan_android/features/products/data/products_repository.dart';
import 'package:wan_android/features/products/domain/product.dart';
import 'package:wan_android/features/products/presentation/providers/products_providers.dart';

Product product(int id) => Product(
  id: id,
  title: '商品$id',
  description: '',
  category: 'test',
  price: 10,
  discountPercentage: 0,
  rating: 4,
  stock: 10,
  thumbnail: '',
  images: [],
  tags: null,
);
ProductListResponse page(int id) =>
    ProductListResponse(products: [product(id)], total: 10, skip: 0, limit: 20);

class FeedRepository extends ProductsRepository {
  FeedRepository() : super(dio: Dio());
  int firstPageCalls = 0;
  final appendStarted = Completer<void>();
  final append = Completer<ProductListResponse>();
  @override
  Future<ProductListResponse> fetchProducts({
    int limit = 20,
    int skip = 0,
  }) async {
    if (skip == 0) return page(++firstPageCalls);
    if (!appendStarted.isCompleted) appendStarted.complete();
    return append.future;
  }
}

class NoCache extends ProductsCache {
  @override
  Future<List<Product>?> load() async => null;
  @override
  Future<void> save(List<Product> products) async {}
}

class CallbackRepository extends ProductsRepository {
  CallbackRepository(this.fetch) : super(dio: Dio());
  final Future<ProductListResponse> Function(int) fetch;
  int calls = 0;
  @override
  Future<ProductListResponse> fetchProducts({int limit = 20, int skip = 0}) {
    calls++;
    return fetch(skip);
  }
}

class BrokenCache extends ProductsCache {
  @override
  Future<List<Product>?> load() async => throw StateError('缓存读取失败');
  @override
  Future<void> save(List<Product> products) async => throw StateError('缓存保存失败');
}

void main() {
  test('刷新后旧分页结果不能追加到新列表', () async {
    final repo = FeedRepository();
    final container = ProviderContainer(
      overrides: [
        productsRepositoryProvider.overrideWithValue(repo),
        productsCacheProvider.overrideWithValue(NoCache()),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(productListProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(productListProvider.future);
    final append = container.read(productListProvider.notifier).loadMore();
    await repo.appendStarted.future;
    await container.refresh(productListProvider.future);
    repo.append.complete(page(99));
    await append;
    expect(
      container
          .read(productListProvider)
          .requireValue
          .products
          .map((e) => e.id),
      [2],
    );
  });
  ProviderContainer createContainer(
    ProductsRepository repo, {
    ProductsCache? cache,
  }) {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        productsRepositoryProvider.overrideWithValue(repo),
        productsCacheProvider.overrideWithValue(cache ?? NoCache()),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(productListProvider, (_, _) {});
    addTearDown(sub.close);
    return container;
  }

  test('重复加载共享任务，加载标志可被订阅', () async {
    final repo = FeedRepository();
    final container = createContainer(repo);
    await container.read(productListProvider.future);
    final notifier = container.read(productListProvider.notifier);
    final first = notifier.loadMore();
    final second = notifier.loadMore();
    expect(identical(first, second), isTrue);
    expect(
      container.read(productListProvider).requireValue.isLoadingMore,
      isTrue,
    );
    repo.append.complete(page(2));
    await first;
    expect(
      container.read(productListProvider).requireValue.isLoadingMore,
      isFalse,
    );
    expect(
      container.read(productListProvider).requireValue.products,
      hasLength(2),
    );
  });
  test('分页失败保留列表，重试成功清除分页错误', () async {
    bool fail = true;
    final repo = CallbackRepository((skip) async {
      if (skip == 0) return page(1);
      if (fail) throw const NetworkException('断网');
      return page(2);
    });
    final container = createContainer(repo);
    await container.read(productListProvider.future);
    final notifier = container.read(productListProvider.notifier);
    await notifier.loadMore();
    expect(
      container.read(productListProvider).requireValue.products.single.id,
      1,
    );
    expect(
      container.read(productListProvider).requireValue.appendError,
      isA<NetworkException>(),
    );
    fail = false;
    await notifier.loadMore();
    expect(
      container.read(productListProvider).requireValue.products,
      hasLength(2),
    );
    expect(
      container.read(productListProvider).requireValue.appendError,
      isNull,
    );
  });
  test('空分页停止继续请求', () async {
    final repo = CallbackRepository(
      (skip) async => skip == 0
          ? page(1)
          : const ProductListResponse(
              products: [],
              total: 10,
              skip: 1,
              limit: 20,
            ),
    );
    final container = createContainer(repo);
    await container.read(productListProvider.future);
    final notifier = container.read(productListProvider.notifier);
    await notifier.loadMore();
    await notifier.loadMore();
    expect(repo.calls, 2);
    expect(container.read(productListProvider).requireValue.hasMore, isFalse);
  });
  test('销毁后迟到的分页不发布状态', () async {
    final repo = FeedRepository();
    final container = ProviderContainer(
      overrides: [
        productsRepositoryProvider.overrideWithValue(repo),
        productsCacheProvider.overrideWithValue(NoCache()),
      ],
    );
    container.listen(productListProvider, (_, _) {});
    await container.read(productListProvider.future);
    final operation = container.read(productListProvider.notifier).loadMore();
    await repo.appendStarted.future;
    container.dispose();
    repo.append.complete(page(99));
    await operation;
  });
  test('缓存写入失败不影响网络首屏', () async {
    final container = createContainer(
      CallbackRepository((_) async => page(1)),
      cache: BrokenCache(),
    );
    final feed = await container.read(productListProvider.future);
    expect(feed.products.single.id, 1);
    await Future<void>.delayed(Duration.zero);
  });
  test('缓存读取失败保留原网络错误', () async {
    final container = createContainer(
      CallbackRepository((_) async => throw const NetworkException('断网')),
      cache: BrokenCache(),
    );
    await expectLater(
      container.read(productListProvider.future),
      throwsA(isA<NetworkException>()),
    );
  });
}
