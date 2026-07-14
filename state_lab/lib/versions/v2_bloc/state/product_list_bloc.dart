import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';

/// 场景①：异步三态 + 分页，事件驱动版。对照 S2 的 ProductListModel：
/// 那边是"调方法 → 改字段 → notifyListeners"；这边是"add(事件) → 处理器
/// → emit(不可变新状态)"。多花的样板（event 类型 + copyWith）换来的是
/// 状态转移可 blocTest 断言值序列、可回放。

enum ListStatus { initial, loading, success, failure }

sealed class ProductListEvent {}

/// 首屏加载（≈ v0 的 initState 首载）。
class ProductListStarted extends ProductListEvent {}

/// 下拉刷新：清空重来。
class ProductListRefreshed extends ProductListEvent {}

/// 触底加载更多。
class ProductListLoadMore extends ProductListEvent {}

class ProductListState extends Equatable {
  const ProductListState({
    this.status = ListStatus.initial,
    this.items = const [],
    this.hasMore = true,
    this.loadingMore = false,
    this.error,
    this.skip = 0,
  });

  final ListStatus status;
  final List<Product> items;
  final bool hasMore;
  final bool loadingMore;
  final String? error;
  final int skip;

  ProductListState copyWith({
    ListStatus? status,
    List<Product>? items,
    bool? hasMore,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    int? skip,
  }) {
    return ProductListState(
      status: status ?? this.status,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      skip: skip ?? this.skip,
    );
  }

  @override
  List<Object?> get props => [status, items, hasMore, loadingMore, error, skip];
}

class ProductListBloc extends Bloc<ProductListEvent, ProductListState> {
  ProductListBloc(this.api) : super(const ProductListState()) {
    on<ProductListStarted>(_onStarted);
    on<ProductListRefreshed>(_onStarted); // 刷新 = 重新首载，复用同一处理器
    // droppable：一次加载更多没跑完，期间再来的 LoadMore 直接丢——
    // 这就是 v1 那句 `if (_loadingMore) return;` 的声明式替身。
    on<ProductListLoadMore>(_onLoadMore, transformer: droppable());
  }

  /// 暴露给页面 onScroll / 测试断言用（不参与状态）。
  final ProductApi api;

  Future<void> _onStarted(
    ProductListEvent event,
    Emitter<ProductListState> emit,
  ) async {
    emit(state.copyWith(status: ListStatus.loading, clearError: true));
    try {
      final page = await api.fetchProducts(skip: 0);
      emit(state.copyWith(
        status: ListStatus.success,
        items: page.products,
        skip: page.products.length,
        hasMore: page.hasMore,
      ));
    } catch (e) {
      emit(state.copyWith(status: ListStatus.failure, error: '加载失败：$e'));
    }
  }

  Future<void> _onLoadMore(
    ProductListLoadMore event,
    Emitter<ProductListState> emit,
  ) async {
    if (!state.hasMore) return; // 到底了就别发（droppable 管并发，这管边界）
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await api.fetchProducts(skip: state.skip);
      emit(state.copyWith(
        items: [...state.items, ...page.products],
        skip: state.skip + page.products.length,
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      // 加载更多失败不打断已有列表（v0/v1 语义原样保留）
      emit(state.copyWith(loadingMore: false));
    }
  }
}
