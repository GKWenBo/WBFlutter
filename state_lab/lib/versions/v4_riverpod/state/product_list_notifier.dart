import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/product.dart';
import 'api_provider.dart';

/// 场景①的数据体：只装"成功态"的内容。loading/error 两态**不在这里**——
/// 它们由 AsyncValue 内建（riverpod 的独门戏：异步三态是类型，不是你
/// 自己维护的三个字段）。对照 v1/v2/v3 每版手搓的 loading/error/status。
class ProductListData extends Equatable {
  const ProductListData({
    required this.items,
    required this.skip,
    required this.hasMore,
    this.loadingMore = false,
  });

  final List<Product> items;
  final int skip;
  final bool hasMore;
  final bool loadingMore;

  ProductListData copyWith({
    List<Product>? items,
    int? skip,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return ProductListData(
      items: items ?? this.items,
      skip: skip ?? this.skip,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }

  @override
  List<Object?> get props => [items, skip, hasMore, loadingMore];
}

/// 场景①：AsyncNotifier——build() 返回 Future，首屏 loading / 失败 error /
/// 成功 data 三态全由框架落进 AsyncValue，UI 端穷尽匹配。
/// 首载 = build 本身（对照 v1 的 ..loadFirst()、v2 的 ..add(Started())：
/// riverpod 里"创建即加载"是 build 的天然语义，连级联调用都省了）。
/// 刷新 = ref.invalidate（重跑 build）；加载更多 = 在 data 态上原地更新。
class ProductListNotifier extends AsyncNotifier<ProductListData> {
  @override
  Future<ProductListData> build() async {
    final page = await ref.read(productApiProvider).fetchProducts(skip: 0);
    return ProductListData(
      items: page.products,
      skip: page.products.length,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final data = state.value; // riverpod 3 的 value 即"有数据给数据，没有给 null"
    // 防重入布尔在 data 里（v1 同款语义）；无数据/到底了直接走人
    if (data == null || data.loadingMore || !data.hasMore) return;
    state = AsyncData(data.copyWith(loadingMore: true));
    try {
      final page =
          await ref.read(productApiProvider).fetchProducts(skip: data.skip);
      state = AsyncData(data.copyWith(
        items: [...data.items, ...page.products],
        skip: data.skip + page.products.length,
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      // 加载更多失败不打断已有列表（v0–v3 语义原样保留）：
      // 不能把整个 state 打成 AsyncError，那会让 UI 掉进全屏错误态
      state = AsyncData(data.copyWith(loadingMore: false));
    }
  }
}

/// autoDispose = 页面级生命周期的 riverpod 姿势：最后一个监听者（页面）
/// 走了，provider 自动销毁；下次进页面重建重载。对照 v1/v2 页面级
/// create/dispose 托管——同一件事，判断依据从"挂在哪棵子树"换成
/// "还有没有人 watch"。
final productListProvider = AsyncNotifierProvider.autoDispose<
    ProductListNotifier, ProductListData>(ProductListNotifier.new);
