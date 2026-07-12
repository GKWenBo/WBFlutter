import 'package:flutter/material.dart';

import '../../../shared/widgets/rebuild_badge.dart';
import '../state/cart_controller.dart';
import '../state/mini_provider.dart';

/// 场景③跨页共享 + 场景④派生状态。
/// ⭐ 看类型：StatefulWidget → StatelessWidget。S0 时本页没有任何
/// 自己的状态，却被迫 Stateful——只为能 setState 通知自己。
/// 现在整页在 build 里 of() 依赖 controller：谁改购物车，本页自动重建。
class V0CartPage extends StatelessWidget {
  const V0CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 整页都在展示购物车——页面级依赖是合理粒度，直接在页面 build 里 of()。
    final cart = MiniProvider.of<CartController>(context);
    final items = cart.items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('购物车'),
        actions: [
          TextButton(
            // 对照 S0：这里曾是 onClearCart() + setState(){} 双保险。
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
                  // onDismissed 仍须立刻删数据（Dismissible 铁律），
                  // remove 里自带 notifyListeners，本页跟着重建。
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
