import 'package:flutter/material.dart';

import '../../../shared/models/cart_item.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import 'cart_page.dart';

/// 场景②：局部 UI 状态（收藏心形只活在本页，页面销毁即消失）——
/// 这是 setState 的舒适区，五个版本里它都不该进全局状态。
class V0ProductDetailPage extends StatefulWidget {
  const V0ProductDetailPage({
    super.key,
    required this.product,
    required this.cart,
    required this.onAddToCart,
    required this.onChangeQty,
    required this.onRemoveItem,
    required this.onClearCart,
  });

  final Product product;
  final List<CartItem> cart;
  final ValueChanged<Product> onAddToCart;
  final void Function(int productId, int delta) onChangeQty;
  final ValueChanged<int> onRemoveItem;
  final VoidCallback onClearCart;

  @override
  State<V0ProductDetailPage> createState() => _V0ProductDetailPageState();
}

class _V0ProductDetailPageState extends State<V0ProductDetailPage> {
  bool _favorite = false;

  int get _cartCount => widget.cart.fold(0, (sum, it) => sum + it.quantity);

  void _openCart() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => V0CartPage(
        cart: widget.cart,
        onChangeQty: widget.onChangeQty,
        onRemoveItem: widget.onRemoveItem,
        onClearCart: widget.onClearCart,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;
    return Scaffold(
      appBar: AppBar(
        title: Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: '收藏',
            icon: Icon(
              _favorite ? Icons.favorite : Icons.favorite_border,
              color: _favorite ? Colors.redAccent : null,
            ),
            // 局部状态：本页 setState 就够了，跟谁都不共享。
            onPressed: () => setState(() => _favorite = !_favorite),
          ),
          CartIconButton(count: _cartCount, onPressed: _openCart),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              product.thumbnail,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 220,
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.image_not_supported_outlined, size: 48),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(product.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('${product.brand ?? '无品牌'} · ⭐${product.rating}',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text('\$${product.price.toStringAsFixed(2)}',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 16),
          Text(product.description, style: theme.textTheme.bodyLarge),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton.icon(
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('加入购物车'),
            onPressed: () {
              widget.onAddToCart(widget.product);
              // ⭐ 痛点展品 2「双重 setState」：上面那行已经让根 setState 了，
              // 但本页是 push 出来的兄弟路由、不在根的子树里，没人来重建它——
              // 想让 AppBar 角标 +1，必须自己再空 setState 一次。
              // 忘了这一步，角标就"陈旧"了：这类 bug 在 setState 时代极常见。
              setState(() {});
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('已加入购物车')));
            },
          ),
        ),
      ),
    );
  }
}
