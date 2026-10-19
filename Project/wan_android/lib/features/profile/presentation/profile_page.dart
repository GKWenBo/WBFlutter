import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_env.dart';
import '../../../core/error/error_messages.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/run_ui_action.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/api.dart';
import '../../cart/api.dart';
import '../../favorites/api.dart';
import '../../orders/api.dart';
import '../../settings/ui.dart';

/// 我的页。M8 起接入登录鉴权：go_router 的 redirect 已经保证"未登录进不了这一页"
/// （见 app/router/app_router.dart），所以这里只管展示已登录用户的信息 + 登出入口。
/// M9 加菜单区（我的收藏入口）。M12 国际化进阶加"语言"行。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.logout,
            onPressed: () => runUiAction(
              context,
              () => ref.read(authProvider.notifier).logout(),
            ),
          ),
        ],
      ),
      body: authState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: l10n.profileLoadFailed(l10n.describeError(error)),
          onRetry: () => ref.invalidate(authProvider),
        ),
        data: (user) {
          if (user == null) {
            // 正常流程走不到这里（redirect 已拦截）；留个兜底避免空白页。
            return Center(child: Text(l10n.notLoggedIn));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(user.image),
                // 头像图裂了不该让整页崩掉（也不该让 widget 测试因"图片加载失败"报错）——
                // 给个空实现相当于"吞掉"这个错误，≈ 你在 iOS 里给 SDWebImage 配的失败占位逻辑。
                onBackgroundImageError: (_, _) {},
              ),
              const SizedBox(height: 16),
              Text(
                user.fullName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '@${user.username}',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              _buildMenu(context, ref),
              const SizedBox(height: 24),
              _buildFooter(context, ref),
            ],
          );
        },
      ),
    );
  }

  /// 菜单区：Card 包一组 ListTile（≈ UITableView 的 insetGrouped 分组样式）。
  /// 每行 = ListTile（M6 分类页用过）：leading 图标 / title 文案 / trailing 附加信息+箭头。
  Widget _buildMenu(BuildContext context, WidgetRef ref) {
    // 只订阅派生的"数量"provider：列表内容怎么变不关心，数字变了才重建这块。
    final favCount = ref.watch(favoritesCountProvider);
    final orderCount = ref.watch(ordersCountProvider);
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _menuRow(
            context,
            icon: Icons.favorite_border,
            title: l10n.favoritesTitle,
            count: favCount,
            onTap: () => context.push('/favorites'),
          ),
          const Divider(height: 1, indent: 56), // indent 对齐文字起点，图标下不压线
          _menuRow(
            context,
            icon: Icons.receipt_long_outlined,
            title: l10n.ordersTitle,
            count: orderCount,
            onTap: () => context.push('/orders'),
          ),
          const Divider(height: 1, indent: 56),
          // M12：语言行由 settings 模块提供（通过 ui.dart 公开入口引用），
          // 本页不关心"语言存在哪、怎么切"。
          const LanguageMenuTile(),
        ],
      ),
    );
  }

  /// 页脚：展示当前环境 + 购物车件数。
  /// 用来演示 M12 两个国际化知识点：
  ///   - 带占位符的文案 currentEnv('{name}')：把变量拼进翻译，≈ iOS 的 String(format:)。
  ///   - ICU 复数 cartItemCount('{count, plural, ...}')：0/1/多 自动选不同措辞，
  ///     ≈ iOS 的 .stringsdict——但写在同一个 arb 键里，不用单独文件。
  Widget _buildFooter(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cartCount = ref.watch(cartTotalCountProvider);
    final grey = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Colors.grey);
    return Column(
      children: [
        Text(l10n.currentEnv(AppEnv.current.flavor.name), style: grey),
        const SizedBox(height: 4),
        Text(l10n.cartItemCount(cartCount), style: grey),
      ],
    );
  }

  /// 菜单行模板：图标 + 标题 + （数量）+ 箭头。
  Widget _menuRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int count,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Row(
        // Row 默认撑满整行会把 trailing 挤爆，mainAxisSize.min 让它只占内容宽度
        //（≈ 内容自适应的 intrinsic size）。
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0)
            Text(
              '$count',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          // chevron_right 自带 matchTextDirection: true：阿语下自动翻成向左（M12）。
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}
