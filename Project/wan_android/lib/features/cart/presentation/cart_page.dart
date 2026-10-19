import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/error_messages.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/run_ui_action.dart';
import '../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cartTitle),
        actions: [
          if ((asyncItems.asData?.value ?? const []).isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.cartClear,
              onPressed: () => runUiAction(
                context,
                () => ref.read(cartProvider.notifier).clear(),
              ),
            ),
        ],
      ),
      body: asyncItems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: l10n.describeError(e),
          onRetry: () => ref.invalidate(cartProvider),
        ),
        data: (items) => items.isEmpty
            ? Center(child: Text(l10n.cartEmpty))
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
                        l10n.totalAmount(totalPrice),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    FilledButton(
                      // M10：push 到结算页。/checkout 在鉴权表里，
                      // 未登录会被 redirect 拦去登录页，登录成功后可再进入结算页。
                      onPressed: () => context.push('/checkout'),
                      child: Text(l10n.cartCheckout),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// 购物车单行：图 + 标题/单价 + 数量步进器 + 滑动删除。
class _CartRow extends ConsumerStatefulWidget {
  final CartItem item;
  const _CartRow({required this.item});

  @override
  ConsumerState<_CartRow> createState() => _CartRowState();
}

class _CartRowState extends ConsumerState<_CartRow> {
  bool _busy = false;
  Future<bool> _perform(Future<void> Function() action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    final success = await runUiAction(context, action);
    if (mounted) setState(() => _busy = false);
    return success;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    // Dismissible：左右滑动删除一行 ≈ UITableView 的滑动删除手势。
    // key 必须唯一且稳定，否则滑动动画/状态会错位。
    // M12 RTL：endToStart 是"从行尾往行首滑"——中文/德语是从右往左，阿语自动变成从左往右，
    // 和 iOS trailingSwipeActions 跟随语言方向是一个意思。
    return Dismissible(
      key: ValueKey(item.productId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _perform(
        () => ref.read(cartProvider.notifier).removeItem(item.productId),
      ),
      background: Container(
        // M12 RTL：原来是 Alignment.centerRight（物理右）。滑动方向会随语言镜像，
        // 垃圾桶图标却钉死在右边——阿语下滑开后露出的一侧是空的。
        // AlignmentDirectional.centerEnd = "行尾"，LTR 是右、RTL 是左，跟着滑动方向走。
        alignment: AlignmentDirectional.centerEnd,
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
                      AppLocalizations.of(context).priceValue(item.unitPrice),
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
                    onPressed: _busy
                        ? null
                        : () => _perform(
                            () => ref
                                .read(cartProvider.notifier)
                                .updateQuantity(
                                  item.productId,
                                  item.quantity - 1,
                                ),
                          ),
                  ),
                  Text('${item.quantity}'),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _busy
                        ? null
                        : () => _perform(
                            () => ref
                                .read(cartProvider.notifier)
                                .updateQuantity(
                                  item.productId,
                                  item.quantity + 1,
                                ),
                          ),
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
