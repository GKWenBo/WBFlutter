import 'package:flutter/material.dart';

import '../models/product.dart';

/// 商品卡片（纯展示：只收数据和回调，不 import 任何状态库——设计文档硬约束）。
/// 类比 iOS：一个只暴露 configure(with:) 和 delegate 回调的 UITableViewCell。
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAddToCart,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            product.thumbnail,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            // errorBuilder 兜底：弱网/测试环境（flutter_test 的假 HttpClient
            // 对一切请求回 400）都靠它保证不红屏。
            errorBuilder: (_, _, _) => Container(
              width: 56,
              height: 56,
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          ),
        ),
        title: Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${product.brand ?? '无品牌'} · ⭐${product.rating}   \$${product.price.toStringAsFixed(2)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_shopping_cart),
          tooltip: '加入购物车',
          onPressed: onAddToCart,
        ),
      ),
    );
  }
}
