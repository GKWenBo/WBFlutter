import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_view.dart';
import '../../products/presentation/widgets/product_grid.dart';
import 'providers/favorites_providers.dart';

/// 收藏页。从"我的"页菜单进入（/favorites）。
///
/// 注意这一页展示的数据全部来自本地快照（FavoritesStorage），**不发网络请求**——
/// 断网也能打开，这是"存快照而不是存 id"换来的能力。
/// 页面结构薄到几乎没有新东西：三态 + 复用 M6 抽出的 ProductGrid（点卡片仍进详情页）。
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favState = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: favState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: '收藏读取失败：$e',
          onRetry: () => ref.invalidate(favoritesProvider),
        ),
        data: (products) => ProductGrid(
          products: products,
          emptyHint: '还没有收藏的商品，去详情页点 ♥ 收藏吧',
        ),
      ),
    );
  }
}
