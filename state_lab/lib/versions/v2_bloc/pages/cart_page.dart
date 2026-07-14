import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/widgets/rebuild_badge.dart';
import '../state/cart_cubit.dart';
import '../state/cart_state.dart';

/// 场景③④。整页展示购物车 → BlocBuilder 整页订阅（= v1 `context.watch`
/// 同粒度）。回调用 `context.read<CartCubit>()` 拿 cubit 调方法。
class V2CartPage extends StatelessWidget {
  const V2CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('购物车'),
        actions: [
          // clear 按钮 enable 与否也吃 state → 放进 BlocBuilder 里。
          BlocBuilder<CartCubit, CartState>(
            buildWhen: (p, c) => p.isEmpty != c.isEmpty,
            builder: (context, state) => TextButton(
              onPressed: state.isEmpty ? null : context.read<CartCubit>().clear,
              child: const Text('清空'),
            ),
          ),
        ],
      ),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) {
          final items = state.items;
          if (state.isEmpty) {
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
                onDismissed: (_) =>
                    context.read<CartCubit>().remove(item.product.id),
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
                        onPressed: () =>
                            context.read<CartCubit>().changeQty(item.product.id, -1),
                      ),
                      Text('${item.quantity}', style: theme.textTheme.titleMedium),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () =>
                            context.read<CartCubit>().changeQty(item.product.id, 1),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) => state.isEmpty
            ? const SizedBox.shrink()
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: RebuildBadge(
                    label: '合计栏',
                    child: Row(
                      children: [
                        Text('共 ${state.totalCount} 件',
                            style: theme.textTheme.bodyLarge),
                        const Spacer(),
                        Text(
                          '合计 \$${state.totalPrice.toStringAsFixed(2)}',
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
