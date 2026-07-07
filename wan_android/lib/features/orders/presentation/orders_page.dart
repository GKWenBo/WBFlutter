import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_view.dart';
import '../domain/order.dart';
import 'providers/orders_providers.dart';

/// 订单列表页（/orders）。从"我的"页菜单进入，或下单成功后跳转过来。
class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersState = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的订单')),
      body: ordersState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: '订单读取失败：$e',
          onRetry: () => ref.invalidate(ordersProvider),
        ),
        data: (orders) => orders.isEmpty
            ? const Center(child: Text('还没有订单，去下一单试试吧'))
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _OrderCard(order: orders[i]),
              ),
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

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      // ExpansionTile：自带展开/收起交互的列表行 ≈ UITableView 的可折叠 section
      // （iOS 得自己维护 isExpanded + insert/deleteRows，这里框架全包了，
      // 还自带箭头旋转动画）。它是 StatefulWidget，展开状态自己管，父组件无感。
      child: ExpansionTile(
        // 展开区域自己带 padding，收起标题区沿用 ListTile 布局，两者视觉对齐。
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Row(
          children: [
            Expanded(child: Text('单号 ${order.id}', style: text.titleSmall)),
            // 状态角标：读增强枚举上的 label，UI 不写 switch。
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                order.status.label,
                style: text.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${_formatTime(order.createdAt)} · 共 ${order.totalCount} 件 · '
            '\$${order.totalPrice.toStringAsFixed(2)}',
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
                    '\$${item.unitPrice.toStringAsFixed(2)} × ${item.quantity}',
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

  /// 手搓的时间格式化（yyyy-MM-dd HH:mm）。
  /// 正经做法是 intl 包的 DateFormat（顺带管多语言），M12 做 i18n 时一起引入，
  /// 现在为一个格式化不值得加依赖。
  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}
