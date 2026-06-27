import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_view.dart';
import '../../products/presentation/widgets/product_grid.dart';
import 'providers/categories_providers.dart';

/// 某分类下的商品页。slug 决定请求哪个分类，title 只用于导航栏展示。
class CategoryProductsPage extends ConsumerWidget {
  final String slug;
  final String title;

  const CategoryProductsPage({
    super.key,
    required this.slug,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // family：按 slug 取对应分类的商品（autoDispose，离开自动清）。
    final async = ref.watch(categoryProductsProvider(slug));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(categoryProductsProvider(slug)),
        ),
        data: (products) => ProductGrid(products: products),
      ),
    );
  }
}
