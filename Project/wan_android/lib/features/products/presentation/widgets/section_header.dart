import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

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
      // M12 RTL：原来是 EdgeInsets.fromLTRB(16, 16, 8, 8)——左 16 右 8 是**物理方向**。
      // 阿语下标题跑到右边、按钮跑到左边，但留白没跟着翻：标题贴着右边缘只剩 8。
      // EdgeInsetsDirectional.fromSTEB = Start/Top/End/Bottom：start 是"行首"，
      // LTR 时在左、RTL 时在右（≈ Auto Layout 的 leading/trailing vs left/right）。
      // 规则：左右**不对称**的间距一律用 Directional；对称的（如 horizontal: 16）无所谓。
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 8, 8),
      child: Row(
        children: [
          // M12 国际化进阶：原来是 Text + Spacer。中文"为你推荐"只有 4 个字，从没出过问题；
          // 换成德语 "Für dich empfohlen" + "Alle anzeigen" 后在 320pt 宽的屏幕上直接 overflow。
          // Row 里放"长度由翻译决定"的文字，必须给它一个可伸缩的容器 + 截断策略：
          // Expanded 吃掉剩余空间（同时把按钮顶到行尾，替代原来的 Spacer），超长时省略号。
          // ≈ Auto Layout 里给 label 设低 compressionResistance，让它先被压缩，而不是把按钮挤出屏幕。
          Expanded(
            child: Text(
              title,
              // Theme.of(context) 取全局主题里的字体规范（≈ 你用 UIFont.preferredFont 取语义字号）。
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onMore != null)
            TextButton(
              onPressed: onMore,
              child: Text(AppLocalizations.of(context).seeAll),
            ),
        ],
      ),
    );
  }
}
