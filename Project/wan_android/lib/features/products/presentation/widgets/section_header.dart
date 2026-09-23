import 'package:flutter/material.dart';

/// 区块标题：左侧大标题 +（可选）右侧「查看全部」。
/// 纯展示、无状态 → StatelessWidget。可复用组件统一放 presentation/widgets/。
class SectionHeader extends StatelessWidget {
  final String title;

  /// 点「查看全部」的回调；为 null 时不显示该按钮（让组件更通用）。
  final VoidCallback? onMore;

  const SectionHeader({super.key, required this.title, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        children: [
          // Theme.of(context) 取全局主题里的字体规范（≈ 你用 UIFont.preferredFont 取语义字号）。
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const Spacer(), // 把后面的内容顶到最右（≈ UIStackView 里的伸缩间隔 / SwiftUI Spacer）
          if (onMore != null)
            TextButton(onPressed: onMore, child: const Text('查看全部')),
        ],
      ),
    );
  }
}
