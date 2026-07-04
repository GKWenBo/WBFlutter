import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/error_view.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../favorites/presentation/providers/favorites_providers.dart';

/// 我的页。M8 起接入登录鉴权：go_router 的 redirect 已经保证"未登录进不了这一页"
/// （见 app/router/app_router.dart），所以这里只管展示已登录用户的信息 + 登出入口。
/// M9 加菜单区（我的收藏入口）。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '退出登录',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: authState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: '加载用户信息失败：$error',
          onRetry: () => ref.invalidate(authProvider),
        ),
        data: (user) {
          if (user == null) {
            // 正常流程走不到这里（redirect 已拦截）；留个兜底避免空白页。
            return const Center(child: Text('未登录'));
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
            ],
          );
        },
      ),
    );
  }

  /// 菜单区：Card 包一组 ListTile（≈ UITableView 的 insetGrouped 分组样式）。
  /// 每行 = ListTile（M6 分类页用过）：leading 图标 / title 文案 / trailing 附加信息+箭头。
  Widget _buildMenu(BuildContext context, WidgetRef ref) {
    // 只订阅派生的"收藏数"：收藏列表内容怎么变不关心，数字变了才重建这块。
    final favCount = ref.watch(favoritesCountProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('我的收藏'),
            trailing: Row(
              // Row 默认撑满整行会把 trailing 挤爆，mainAxisSize.min 让它只占内容宽度
              //（≈ 内容自适应的 intrinsic size）。
              mainAxisSize: MainAxisSize.min,
              children: [
                if (favCount > 0)
                  Text(
                    '$favCount',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.push('/favorites'),
          ),
        ],
      ),
    );
  }
}
