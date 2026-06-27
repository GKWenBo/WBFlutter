import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/product.dart';
import 'product_card.dart';

/// 可复用的商品网格（分类页、搜索页共用）。
/// 它自己是一个可滚动的 GridView，适合"整页就是一个网格"的简单页面。
/// （首页因为上面还有 banner/分类等多段内容，用的是 Sliver 版本，不走这里。）
class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final String emptyHint;

  const ProductGrid({
    super.key,
    required this.products,
    this.emptyHint = '没有找到商品',
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(child: Text(emptyHint));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: products.length,
      itemBuilder: (context, i) {
        final p = products[i];
        return ProductCard(
          title: p.title,
          price: p.discountedPrice,
          imageUrl: p.thumbnail,
          rating: p.rating,
          onTap: () => context.push('/product/${p.id}'),
        );
      },
    );
  }
}
