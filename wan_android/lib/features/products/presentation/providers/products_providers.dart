import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../data/products_cache.dart';
import '../../data/products_repository.dart';
import '../../domain/product.dart';

part 'products_providers.g.dart';

/// 提供 ProductsRepository（依赖注入）。
/// 任何地方 `ref.watch(productsRepositoryProvider)` 都能拿到同一个；
/// 测试时可以 `overrideWith` 换成 mock（这就是 Riverpod 自带的 DI 能力）。
@riverpod
ProductsRepository productsRepository(Ref ref) => ProductsRepository();

/// 首页缓存的 DI provider（测试时同样可 override）。
@riverpod
ProductsCache productsCache(Ref ref) => ProductsCache();

@riverpod
Future<Product> product(Ref ref, int id) {
  return ref.watch(productsRepositoryProvider).fetchProduct(id);
}

/// 商品列表的状态管理 ≈ 你 iOS 的 ViewModel（MVVM）。
///
/// build() 返回一个 Future，Riverpod 会自动把它包成 AsyncValue：
/// 请求中 → loading，成功 → data，抛错 → error。页面只管 .when 渲染，不用自己记 loading 标志。
@riverpod
class ProductList extends _$ProductList {
  static const _pageSize = 20;

  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isFromCache = false;

  /// 是否还有下一页（UI 用它决定要不要显示"加载更多"footer）。
  bool get hasMore => _hasMore;

  /// 当前展示的是否是离线缓存（UI 用它决定要不要显示"离线数据"横幅）。
  bool get isFromCache => _isFromCache;

  @override
  Future<List<Product>> build() async {
    // 首屏：取第一页。这期间页面自动是 loading 态。
    final repo = ref.watch(productsRepositoryProvider);
    final cache = ref.watch(productsCacheProvider);
    try {
      final page = await repo.fetchProducts(limit: _pageSize, skip: 0);
      _hasMore = page.hasMore;
      _isFromCache = false;
      // 拿到新数据顺手写缓存（不 await 的后台副作用，同 Cart._persist）。
      cache.save(page.products);
      return page.products;
    } on AppException {
      // 网络挂了 → 降级读缓存（"stale-while-error"：宁给旧数据，不给白屏）。
      // 只捕获 AppException（网络/服务器/解析），别的错误照常抛——
      // catch 得太宽会把真正的 bug 也吞成"离线态"，排查时很要命。
      final cached = await cache.load();
      if (cached == null || cached.isEmpty) rethrow; // 没缓存可兜 → 维持原错误态
      _hasMore = false; // 离线数据只有这一页，别再触发上拉分页
      _isFromCache = true;
      return cached;
    }
  }

  /// 上拉加载更多：把下一页"追加"到现有列表后面。
  Future<void> loadMore() async {
    // 正在加载、或已经没有更多了，直接返回（防抖/防越界）。
    if (_isLoadingMore || !_hasMore) return;
    final current = state.asData?.value;
    if (current == null) return; // 首屏都还没好（loading/error），不加载更多

    _isLoadingMore = true;
    try {
      final repo = ref.read(productsRepositoryProvider);
      final page = await repo.fetchProducts(
        limit: _pageSize,
        skip: current.length, // 从已有条数之后继续取
      );
      _hasMore = page.hasMore;
      // 手动把新数据合并进 state（≈ tableView 追加 cell 后 reload）。
      state = AsyncData([...current, ...page.products]);
    } catch (e) {
      // 加载更多失败：保留已有数据，不打断用户；下次滚动可再触发。
      debugPrint('loadMore 失败：$e');
    } finally {
      _isLoadingMore = false;
    }
  }
}
