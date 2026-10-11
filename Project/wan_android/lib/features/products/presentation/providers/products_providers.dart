import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../data/products_dependencies.dart';
import '../../domain/product.dart';
import '../../domain/product_feed_state.dart';

part 'products_providers.g.dart';

@riverpod
Future<Product> product(Ref ref, int id) =>
    ref.watch(productsRepositoryProvider).fetchProduct(id);

/// M4 三态 + M9 离线兜底；维护演进：元信息进入状态，并隔离刷新代次。
@riverpod
class ProductList extends _$ProductList {
  static const _pageSize = 20;
  int _generation = 0;
  Future<void>? _append;

  @override
  Future<ProductFeedState> build() async {
    final generation = ++_generation;
    _append = null;
    final repo = ref.watch(productsRepositoryProvider);
    final cache = ref.watch(productsCacheProvider);
    try {
      final page = await repo.fetchProducts(limit: _pageSize, skip: 0);
      if (ref.mounted && generation == _generation) {
        // 副本失败不影响首屏；也处理测试/替代缓存实现抛出的异常。
        unawaited(
          cache.save(page.products).catchError((Object _, StackTrace _) {}),
        );
      }
      return ProductFeedState(
        products: page.products,
        nextSkip: page.skip + page.products.length,
        hasMore: page.products.isNotEmpty && page.hasMore,
      );
    } on AppException {
      List<Product>? cached;
      try {
        cached = await cache.load();
      } catch (_) {
        cached = null;
      }
      if (cached == null || cached.isEmpty) rethrow;
      return ProductFeedState(
        products: cached,
        nextSkip: cached.length,
        hasMore: false,
        isFromCache: true,
      );
    }
  }

  /// 多次触发共享同一项任务；旧代次连 finally 都不能改新状态。
  Future<void> loadMore() {
    if (_append != null) return _append!;
    final current = state.asData?.value;
    if (state.isLoading || current == null || !current.hasMore) {
      return Future.value();
    }
    final generation = _generation;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    final task = _loadMore(current, generation);
    _append = task;
    return task;
  }

  Future<void> _loadMore(ProductFeedState current, int generation) async {
    try {
      final page = await ref
          .read(productsRepositoryProvider)
          .fetchProducts(limit: _pageSize, skip: current.nextSkip);
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        current.copyWith(
          products: [...current.products, ...page.products],
          nextSkip: page.skip + page.products.length,
          hasMore: page.products.isNotEmpty && page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        current.copyWith(isLoadingMore: false, appendError: error),
      );
    } finally {
      if (ref.mounted && generation == _generation) _append = null;
    }
  }
}
