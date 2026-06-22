import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// App 主框架：底部 4 个 Tab（首页/分类/购物车/我的）。≈ UITabBarController。
///
/// M5 起，"当前选中第几个 Tab"由 go_router 的 StatefulShellRoute 管理，
/// 这个 Widget 不再持有 _currentIndex 状态 → 回归清爽的 StatelessWidget。
/// navigationShell 由路由表传入，内部已经是一个 IndexedStack（各 Tab 常驻、保留状态）。
class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // 再次点击已选中的 Tab：回到该 Tab 的根页面（≈ UITabBar 二次点击回到顶）。
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: '分类',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: '购物车',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
