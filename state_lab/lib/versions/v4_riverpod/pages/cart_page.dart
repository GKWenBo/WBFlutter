import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/rebuild_badge.dart';
import '../state/cart_notifier.dart';

/// 场景③④。整页展示购物车 → ref.watch(cartProvider) 整页订阅
/// （= v1 watch / v2 整页 BlocBuilder 同粒度）。回调走
/// ref.read(cartProvider.notifier) 调方法——watch 订阅值、read 拿人办事，
/// 与 Provider 的 watch/read 分工一脉相承。
class V4CartPage extends ConsumerWidget {
  const V4CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cart = ref.watch(cartProvider);
    final items = cart.items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('购物车'),
        actions: [
          TextButton(
            onPressed:
                cart.isEmpty ? null : ref.read(cartProvider.notifier).clear,
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
                  onDismissed: (_) =>
                      ref.read(cartProvider.notifier).remove(item.product.id),
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
                          onPressed: () => ref
                              .read(cartProvider.notifier)
                              .changeQty(item.product.id, -1),
                        ),
                        Text('${item.quantity}',
                            style: theme.textTheme.titleMedium),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => ref
                              .read(cartProvider.notifier)
                              .changeQty(item.product.id, 1),
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
