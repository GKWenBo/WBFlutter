import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../l10n/app_localizations.dart';
import 'router/app_router.dart';

/// 整个 App 的根 Widget。
/// 角色 ≈ iOS 的 AppDelegate/SceneDelegate + UIWindow：装配标题、主题、路由。
///
/// 因为要 ref.watch(routerProvider)，所以是 ConsumerWidget（能访问 Riverpod 的 ref）。
class WanShopApp extends ConsumerWidget {
  const WanShopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // M12：标题不再写死，跟着当前 Flavor 走（dev 会显示 "WanShop Dev"）。
    final env = AppEnv.current;

    // MaterialApp.router：把导航交给 go_router 接管（从 M0 的 home: 升级而来）。
    return MaterialApp.router(
      title: env.appTitle,
      debugShowCheckedModeBanner: false,

      // ---- M12 国际化装配 ----
      // localizationsDelegates：告诉框架"字符串/日期/Material&Cupertino 控件文案"各去哪找翻译。
      // AppLocalizations.localizationsDelegates 已经把自己的 delegate + flutter 内置的三件套打包好了。
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // 支持的语言列表；系统语言命中哪个就用哪个，都不命中用第一个（这里 en）。
      // ≈ iOS 工程里勾选的 Localizations 语言集合。
      supportedLocales: AppLocalizations.supportedLocales,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6F00)),
        useMaterial3: true,
      ),
      routerConfig: router,

      // builder：在整个页面外面再包一层。这里用它按环境盖一个角标水印，
      // 让你一眼看出当前跑的是 dev/staging 还是 prod（prod 不显示）。
      // ≈ iOS 里给非生产包加个红色角标/水印，防止测试包混进生产。
      builder: (context, child) {
        if (!env.showEnvBanner) return child!;
        return Banner(
          message: env.flavor.name.toUpperCase(), // DEV / STAGING
          location: BannerLocation.topEnd,
          color: Colors.redAccent,
          child: child,
        );
      },
    );
  }
}
