import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/cart/presentation/providers/cart_providers.dart';
import '../l10n/app_localizations.dart';

/// App 主框架：底部 4 个 Tab（首页/分类/购物车/我的）。≈ UITabBarController。
///
/// M5 起，"当前选中第几个 Tab"由 go_router 的 StatefulShellRoute 管理，
/// 这个 Widget 不再持有 _currentIndex 状态。
/// M7 起改成 ConsumerWidget：要 ref.watch(cartTotalCountProvider) 给购物车 Tab 画角标——
/// 这正是"同一份全局状态被多处共享"的例子：详情页写、购物车页读、这里也读。
class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 派生 provider：购物车总件数变化时，这里自动重建、角标数字跟着变。
    final cartCount = ref.watch(cartTotalCountProvider);
    // M12：取当前语言的文案。of(context) 从最近的 Localizations 里拿（app.dart 已装配 delegate）。
    // ≈ iOS 的 NSLocalizedString，但类型安全：拼错 key 编译期就报错，不会静默返回原字符串。
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // 再次点击已选中的 Tab：回到该 Tab 的根页面（≈ UITabBar 二次点击回到顶）。
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.category_outlined),
            selectedIcon: const Icon(Icons.category),
            label: l10n.navCategory,
          ),
          NavigationDestination(
            // Badge ≈ UITabBarItem.badgeValue：数字为 0 时不显示（isLabelVisible 控制）。
            icon: Badge(
              label: Text('$cartCount'),
              isLabelVisible: cartCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: Badge(
              label: Text('$cartCount'),
              isLabelVisible: cartCount > 0,
              child: const Icon(Icons.shopping_cart),
            ),
            label: l10n.navCart,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
