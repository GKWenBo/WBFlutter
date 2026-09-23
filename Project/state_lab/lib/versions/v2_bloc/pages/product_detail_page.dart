import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/product.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../state/cart_cubit.dart';
import 'cart_page.dart';

/// 场景②：收藏心形仍页面 setState——"一个人看的状态留在页面"，五版一致。
class V2ProductDetailPage extends StatefulWidget {
  const V2ProductDetailPage({super.key, required this.product});

  final Product product;

  @override
  State<V2ProductDetailPage> createState() => _V2ProductDetailPageState();
}

class _V2ProductDetailPageState extends State<V2ProductDetailPage> {
  bool _favorite = false;

  void _openCart() {
    final cart = context.read<CartCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(value: cart, child: const V2CartPage()),
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
            onPressed: () => setState(() => _favorite = !_favorite),
          ),
          // context.select：BlocSelector 的函数式写法，选 totalCount 标量。
          Builder(builder: (context) {
            final count = context.select<CartCubit, int>((c) => c.state.totalCount);
            return CartIconButton(count: count, onPressed: _openCart);
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
              context.read<CartCubit>().add(widget.product);
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
