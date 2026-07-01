import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_view.dart';
import '../domain/cart_item.dart';
import 'providers/cart_providers.dart';

/// 购物车页：整页读取同一份全局 Cart 状态（详情页写入的那份）。
class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // cartProvider 现在是 AsyncNotifier（初始值要异步读盘），
    // 所以是 AsyncValue<List<CartItem>>，要用 .when 渲染三态（磁盘读取很快，loading 几乎不可见）。
    final asyncItems = ref.watch(cartProvider);
    final totalPrice = ref.watch(cartTotalPriceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('购物车'),
        actions: [
          if ((asyncItems.asData?.value ?? const []).isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '清空购物车',
              onPressed: () => ref.read(cartProvider.notifier).clear(),
            ),
        ],
      ),
      body: asyncItems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(cartProvider),
        ),
        data: (items) => items.isEmpty
            ? const Center(child: Text('购物车是空的，快去逛逛吧'))
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _CartRow(item: items[i]),
              ),
      ),
      bottomNavigationBar: (asyncItems.asData?.value ?? const []).isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '合计：\$${totalPrice.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        // 占位：M10 会做成真正的结算流程。
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('结算流程（占位，M10 接真实下单）')),
                        );
                      },
                      child: const Text('去结算'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// 购物车单行：图 + 标题/单价 + 数量步进器 + 滑动删除。
class _CartRow extends ConsumerWidget {
  final CartItem item;
  const _CartRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dismissible：左右滑动删除一行 ≈ UITableView 的滑动删除手势。
    // key 必须唯一且稳定，否则滑动动画/状态会错位。
    return Dismissible(
      key: ValueKey(item.productId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) =>
          ref.read(cartProvider.notifier).removeItem(item.productId),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: item.thumbnail,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorWidget: (c, u, e) => const ColoredBox(
                    color: Color(0x11000000),
                    child: Icon(Icons.image_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${item.unitPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // 数量步进器：Material 没有现成 Stepper，自己拼两个 IconButton + 数字。
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => ref
                        .read(cartProvider.notifier)
                        .updateQuantity(item.productId, item.quantity - 1),
                  ),
                  Text('${item.quantity}'),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => ref
                        .read(cartProvider.notifier)
                        .updateQuantity(item.productId, item.quantity + 1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
