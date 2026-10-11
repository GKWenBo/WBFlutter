import 'product.dart';

/// M4/M9：商品与分页元信息一起发布，≈ 一个不可变 ViewModel 快照。
class ProductFeedState {
  ProductFeedState({
    required List<Product> products,
    required this.nextSkip,
    required this.hasMore,
    this.isLoadingMore = false,
    this.isFromCache = false,
    this.appendError,
  }) : products = List.unmodifiable(products);
  final List<Product> products;
  final int nextSkip;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isFromCache;
  final Object? appendError;

  ProductFeedState copyWith({
    List<Product>? products,
    int? nextSkip,
    bool? hasMore,
    bool? isLoadingMore,
    Object? appendError,
  }) => ProductFeedState(
    products: products ?? this.products,
    nextSkip: nextSkip ?? this.nextSkip,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isFromCache: isFromCache,
    appendError: appendError,
  );
}
