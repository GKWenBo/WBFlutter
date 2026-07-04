import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/cart/presentation/cart_page.dart';
import '../../features/favorites/presentation/favorites_page.dart';
import '../../features/categories/presentation/categories_page.dart';
import '../../features/categories/presentation/category_products_page.dart';
import '../../features/products/presentation/home_page.dart';
import '../../features/products/presentation/product_detail_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/search/presentation/search_page.dart';
import '../main_scaffold.dart';

/// 需要登录才能访问的路径前缀。M8 先只挡"我的"；
/// 后续模块（比如 M10 结算）要加鉴权门槛时，往这个表里加一项就行。
const _protectedPaths = ['/profile'];

/// 桥接器：把 Riverpod 的登录态变化"转发"成 go_router 能听懂的信号。
///
/// go_router 的 redirect 只在"发生一次导航"时被调用一次；
/// 但登出这种状态变化并不来自一次显式导航（用户还停在"我的"页，只是点了个按钮），
/// 这时候必须有人主动告诉 go_router"状态变了，请重新跑一遍 redirect 检查"——
/// 这正是 refreshListenable 存在的意义，≈ 你在 iOS 里用 NotificationCenter/Combine
/// 通知 Coordinator"登录态变了，重新决定当前该展示哪个页面"。
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen(authProvider, (_, _) => notifyListeners());
  }
}

/// 全局路由表 ≈ 你的路由中心 / Coordinator。
///
/// 做成 Provider（而非顶层常量），是为了能在 redirect 里读登录态做"未登录拦截"。
final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _AuthRefreshListenable(ref);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      // 用 read 而不是 watch：redirect 是一次性回调，不是 build 方法，
      // 状态变化靠上面的 refreshListenable 通知 go_router 重新调用它，不需要 watch 帮忙重建。
      final isLoggedIn = ref.read(authProvider).asData?.value != null;
      final goingToLogin = state.matchedLocation == '/login';
      final needsAuth = _protectedPaths.any(
        (path) => state.matchedLocation.startsWith(path),
      );

      if (!isLoggedIn && needsAuth) return '/login'; // 未登录闯鉴权页 → 拦到登录页
      if (isLoggedIn && goingToLogin) return '/home'; // 已登录还想去登录页 → 没必要，送回首页
      return null; // 不拦截，放行原本的目的地
    },
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

      // 收藏页：顶层路由，从"我的"页菜单 push 进入。
      // 注意它**不在** _protectedPaths 里：收藏是"这台设备上的本地数据"，不挂在账号下，
      // 没登录也允许看（对比 /profile 展示的是账号数据，必须登录）。
      // 如果以后收藏改成走服务端接口（挂账号），把 '/favorites' 加进 _protectedPaths 即可。
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const FavoritesPage(),
      ),

      // 登录页：顶层路由，不在 shell 里——未登录被拦截时应该看到一个没有底部 Tab 的全屏页面。
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),

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
