import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/checkout/checkout_controller.dart';
import '../../../core/error/error_messages.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/run_ui_action.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/order.dart';
import 'order_status_text.dart';
import 'providers/orders_providers.dart';

/// 订单列表页（/orders）。从"我的"页菜单进入，或下单成功后跳转过来。
class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersState = ref.watch(ordersProvider);
    final checkout = ref.watch(checkoutControllerProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ordersTitle)),
      body: Column(
        children: [
          if (checkout.needsRetry)
            ListTile(
              title: Text(
                checkout.result!.needsCartRetry
                    ? l10n.orderPendingCartSync
                    : l10n.orderPendingAddressSave,
              ),
              trailing: TextButton(
                onPressed: checkout.isSubmitting
                    ? null
                    : () => runUiAction(context, () async {
                        await ref
                            .read(checkoutControllerProvider.notifier)
                            .retryPending();
                      }),
                child: Text(l10n.retry),
              ),
            ),
          Expanded(
            child: ordersState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: l10n.ordersLoadFailed(l10n.describeError(e)),
                onRetry: () => ref.invalidate(ordersProvider),
              ),
              data: (orders) => orders.isEmpty
                  ? Center(child: Text(l10n.ordersEmpty))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: orders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _OrderCard(order: orders[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个订单卡片：收起时只看摘要，点开展开商品明细 + 收货地址。
class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      // ExpansionTile：自带展开/收起交互的列表行 ≈ UITableView 的可折叠 section
      // （iOS 得自己维护 isExpanded + insert/deleteRows，这里框架全包了，
      // 还自带箭头旋转动画）。它是 StatefulWidget，展开状态自己管，父组件无感。
      child: ExpansionTile(
        // 展开区域自己带 padding，收起标题区沿用 ListTile 布局，两者视觉对齐。
        childrenPadding: const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          12,
        ), // 左右对称，RTL 无需改
        title: Row(
          children: [
            Expanded(
              child: Text(l10n.orderNumber(order.id), style: text.titleSmall),
            ),
            // 状态角标：M10 读增强枚举上的 label；M12 改由展示层按当前语言翻译。
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                order.status.localizedLabel(l10n),
                style: text.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          // M12：时间 / 件数复数 / 金额全部交给 ARB 占位符格式化——
          // 同一个订单，中文显示 "2026/3/7 09:05 · 共 3 件 · $1,234.50"，
          // 德语显示 "7.3.2026 09:05 · 3 Artikel · 1.234,50 $"。
          child: Text(
            l10n.orderSummary(
              order.createdAt,
              l10n.orderItemCount(order.totalCount),
              order.totalPrice,
            ),
            style: text.bodySmall,
          ),
        ),
        children: [
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: item.thumbnail,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => const ColoredBox(
                        color: Color(0x11000000),
                        child: Icon(Icons.image_outlined, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ),
                  Text(
                    l10n.unitPriceTimesQuantity(item.unitPrice, item.quantity),
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          const Divider(height: 16),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: scheme.outline),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${order.address.name} ${order.address.phone} · '
                  '${order.address.detail}',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
