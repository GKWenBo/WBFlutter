import 'package:flutter/material.dart';

import '../../../shared/models/cart_item.dart';
import '../../../shared/widgets/rebuild_badge.dart';

/// 场景③跨页共享 + 场景④派生状态。
/// 本页拿到的 cart 是根传下来的**同一个 List 引用**：读永远最新，
/// 但每次改完都要 onXxx（根 setState）+ 本页 setState 双保险——
/// 一份状态、两处手动通知，这就是 v0 的账。
class V0CartPage extends StatefulWidget {
  const V0CartPage({
    super.key,
    required this.cart,
    required this.onChangeQty,
    required this.onRemoveItem,
    required this.onClearCart,
  });

  final List<CartItem> cart;
  final void Function(int productId, int delta) onChangeQty;
  final ValueChanged<int> onRemoveItem;
  final VoidCallback onClearCart;

  @override
  State<V0CartPage> createState() => _V0CartPageState();
}

class _V0CartPageState extends State<V0CartPage> {
  /// 派生状态示范：合计永远现算，不单独存变量。
  /// 存一份"totalPrice 变量"就得在每个改动点手动同步它——必忘。
  double get _totalPrice =>
      widget.cart.fold(0, (sum, it) => sum + it.lineTotal);
  int get _totalCount => widget.cart.fold(0, (sum, it) => sum + it.quantity);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = widget.cart;
    return Scaffold(
      appBar: AppBar(
        title: const Text('购物车'),
        actions: [
          TextButton(
            onPressed: cart.isEmpty
                ? null
                : () {
                    widget.onClearCart();
                    setState(() {}); // 双重 setState（根 + 本页）
                  },
            child: const Text('清空'),
          ),
        ],
      ),
      body: cart.isEmpty
          ? const Center(child: Text('购物车是空的'))
          : ListView.builder(
              itemCount: cart.length,
              itemBuilder: (context, index) {
                final item = cart[index];
                return Dismissible(
                  key: ValueKey(item.product.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: theme.colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    widget.onRemoveItem(item.product.id);
                    setState(() {}); // 双重 setState
                  },
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
                          onPressed: () {
                            widget.onChangeQty(item.product.id, -1);
                            setState(() {}); // 双重 setState
                          },
                        ),
                        Text('${item.quantity}',
                            style: theme.textTheme.titleMedium),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            widget.onChangeQty(item.product.id, 1);
                            setState(() {}); // 双重 setState
                          },
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
                      Text('共 $_totalCount 件',
                          style: theme.textTheme.bodyLarge),
                      const Spacer(),
                      Text(
                        '合计 \$${_totalPrice.toStringAsFixed(2)}',
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
