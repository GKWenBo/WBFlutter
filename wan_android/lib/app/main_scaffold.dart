import 'package:flutter/material.dart';

import '../features/cart/presentation/cart_page.dart';
import '../features/categories/presentation/categories_page.dart';
import '../features/products/presentation/home_page.dart';
import '../features/profile/presentation/profile_page.dart';

/// App 主框架：底部 4 个 Tab（首页 / 分类 / 购物车 / 我的）。
/// 角色 ≈ iOS 的 UITabBarController。
///
/// 它要"记住当前选中第几个 Tab"，这是会变化的内部状态，
/// 所以用 StatefulWidget（≈ 带 @State 的 SwiftUI View）。
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  // 固定写法：StatefulWidget 把"可变状态"分离到独立的 State 对象里。
  // Widget 本身是不可变的配置，真正存状态、有生命周期的是下面的 _MainScaffoldState。
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  // 当前选中的 Tab 下标，等价于 UITabBarController.selectedIndex。
  int _currentIndex = 0;

  // 4 个 Tab 各自的根页面。每个页面都来自它自己的 feature 目录，互不依赖。
  // 现在都是占位页，后续模块会逐个替换成真实页面。
  final List<Widget> _pages = const [
    HomePage(), // features/products
    CategoriesPage(), // features/categories
    CartPage(), // features/cart
    ProfilePage(), // features/profile
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack 同时保留所有 Tab 页面、只显示选中的那个，
      // 切 Tab 时不重建、能保住每个 Tab 的滚动位置——类似 UITabBarController 让各 VC 常驻。
      body: IndexedStack(index: _currentIndex, children: _pages),
      // NavigationBar 是 Material 3 的底部导航栏（= UITabBar）。
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          // setState 告诉框架"状态变了，请重建本 Widget" → UI 自动刷新。
          // 等价于 SwiftUI 改 @State。切记：只改字段不调 setState，界面不会更新。
          setState(() => _currentIndex = index);
        },
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
