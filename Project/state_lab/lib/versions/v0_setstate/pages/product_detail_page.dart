import 'package:flutter/material.dart';

import '../../../shared/models/product.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../state/cart_controller.dart';
import '../state/mini_provider.dart';
import 'cart_page.dart';

/// 场景②：收藏心形是**局部 UI 状态**，继续 setState——五个版本它都不进全局。
/// ⭐ S0 痛点展品 2、3 谢幕：加购不再双重 setState；进购物车不再
/// await + 手动补刷——角标的 Builder 依赖着 controller，谁改都自动跟。
class V0ProductDetailPage extends StatefulWidget {
  const V0ProductDetailPage({super.key, required this.product});

  final Product product;

  @override
  State<V0ProductDetailPage> createState() => _V0ProductDetailPageState();
}

class _V0ProductDetailPageState extends State<V0ProductDetailPage> {
  bool _favorite = false;

  void _openCart() {
    // 对照 S0：这里曾是 await push + if(mounted) setState 的手工补丁。
    // 现在购物车页清空 → controller 开火 → 本页角标 Builder（依赖者）
    // 立刻重建——pop 回来看到的必然是新值，痛点 3 结构性消失。
    final cart = MiniProvider.read<CartController>(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MiniProvider(notifier: cart, child: const V0CartPage()),
      ),
    );
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
          Builder(builder: (context) {
            final cart = MiniProvider.of<CartController>(context);
            return CartIconButton(count: cart.totalCount, onPressed: _openCart);
          }),
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
              // 一份状态、一处通知：不再需要"根一次 + 本页一次"。
              MiniProvider.read<CartController>(context).add(widget.product);
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
