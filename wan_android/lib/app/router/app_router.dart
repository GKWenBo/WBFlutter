import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/presentation/cart_page.dart';
import '../../features/categories/presentation/categories_page.dart';
import '../../features/categories/presentation/category_products_page.dart';
import '../../features/products/presentation/home_page.dart';
import '../../features/products/presentation/product_detail_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/search/presentation/search_page.dart';
import '../main_scaffold.dart';

/// 全局路由表 ≈ 你的路由中心 / Coordinator。
///
/// 做成 Provider（而非顶层常量），是为了 M8 能在 redirect 里读登录态做"未登录拦截"。
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      // StatefulShellRoute.indexedStack ≈ UITabBarController：
      // 底部若干 Tab，且每个 Tab 拥有自己独立的导航栈（切 Tab 不会丢各自压入的页面）。
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainScaffold(navigationShell: navigationShell),
        branches: [
          // 每个 branch = 一个 Tab 的导航栈。
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (context, state) => const HomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/categories',
                builder: (context, state) => const CategoriesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/cart', builder: (context, state) => const CartPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),

      // 商品详情：顶层路由（不在 shell 里）。
      // 用 context.push 进入时会全屏盖住底部 Tab 栏，≈ iOS push 时 hidesBottomBarWhenPushed = true。
      GoRoute(
        path: '/product/:id', // :id 是路径参数（path parameter）
        builder: (context, state) {
          // 路径参数永远是 String，自己转成 int（≈ segue 传参后做类型转换）。
          final id = int.parse(state.pathParameters['id']!);
          return ProductDetailPage(id: id);
        },
      ),

      // 搜索页。
      GoRoute(path: '/search', builder: (context, state) => const SearchPage()),

      // 某分类的商品页：slug 进路径，展示名通过 extra 传（不进 URL）。
      GoRoute(
        path: '/category/:slug',
        builder: (context, state) {
          final slug = state.pathParameters['slug']!;
          final name = state.extra as String? ?? slug;
          return CategoryProductsPage(slug: slug, title: name);
        },
      ),
    ],
  );
});
