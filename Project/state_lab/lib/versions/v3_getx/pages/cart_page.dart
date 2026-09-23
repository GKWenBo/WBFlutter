import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../shared/widgets/rebuild_badge.dart';
import '../state/cart_getx_controller.dart';

/// 场景③④。整页展示购物车 → Obx 自动挡整页订阅（读到 items 即登记，
/// 粒度 = v1 watch / v2 整页 BlocBuilder）。注意页面没收任何参数、也
/// 没人 re-provide——`Get.find` 直捞全局注册表，这是 GetX 最顺手的一面。
class V3CartPage extends StatelessWidget {
  const V3CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = Get.find<CartGetxController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('购物车'),
        actions: [
          Obx(
            () => TextButton(
              onPressed: cart.isEmpty ? null : cart.clear,
              child: const Text('清空'),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final items = cart.items;
        if (cart.isEmpty) {
          return const Center(child: Text('购物车是空的'));
        }
        return ListView.builder(
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
                subtitle: Text('\$${item.product.price.toStringAsFixed(2)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => cart.changeQty(item.product.id, -1),
                    ),
                    Text('${item.quantity}', style: theme.textTheme.titleMedium),
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
        );
      }),
      bottomNavigationBar: Obx(
        () => cart.isEmpty
            ? const SizedBox.shrink()
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
      ),
    );
  }
}
