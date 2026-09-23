import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/rebuild_badge.dart';
import '../state/cart_model.dart';

/// 场景③④。整页展示购物车 → context.watch 页面级依赖（与 S1 的 of()
/// 同粒度、同理由）。Stateless 从 S1 延续——"假 Stateful"退场是结构
/// 红利，不是 Provider 专属。
class V1CartPage extends StatelessWidget {
  const V1CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartModel>();
    final items = cart.items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('购物车'),
        actions: [
          TextButton(
            onPressed: cart.isEmpty ? null : cart.clear,
            child: const Text('清空'),
          ),
        ],
      ),
      body: cart.isEmpty
          ? const Center(child: Text('购物车是空的'))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Dismissible(
                  key: ValueKey(item.product.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: theme.colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => cart.remove(item.product.id),
                  child: ListTile(
                    title: Text(item.product.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle:
                        Text('\$${item.product.price.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => cart.changeQty(item.product.id, -1),
                        ),
                        Text('${item.quantity}',
                            style: theme.textTheme.titleMedium),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => cart.changeQty(item.product.id, 1),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: RebuildBadge(
                  label: '合计栏',
                  child: Row(
                    children: [
                      Text('共 ${cart.totalCount} 件',
                          style: theme.textTheme.bodyLarge),
                      const Spacer(),
                      Text(
                        '合计 \$${cart.totalPrice.toStringAsFixed(2)}',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
