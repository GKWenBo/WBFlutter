import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../features/settings/api.dart';
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
    // M12 国际化进阶：用户在 App 内手选的语言；null = 跟随系统。
    // 还在读盘（loading）时也是 null —— 冷启动第一帧可能先按系统语言画，读完再切过去。
    // 要彻底消除这一闪，可以在 main() 里先 await 读出偏好再 override 进 ProviderScope；
    // 这里为保持 main.dart 极薄没有这么做（读 shared_preferences 只要几毫秒，通常看不出来）。
    final userLocale = ref.watch(appLocaleProvider).asData?.value;

    // MaterialApp.router：把导航交给 go_router 接管（从 M0 的 home: 升级而来）。
    return MaterialApp.router(
      title: env.appTitle,
      debugShowCheckedModeBanner: false,

      // ---- M12 国际化装配 ----
      // localizationsDelegates：告诉框架"字符串/日期/Material&Cupertino 控件文案"各去哪找翻译。
      // AppLocalizations.localizationsDelegates 已经把自己的 delegate + flutter 内置的三件套打包好了
      // （所以 ar/de 下返回按钮的 tooltip、日期选择器、"粘贴/全选"菜单也会自动是阿语/德语）。
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // 支持的语言列表；系统语言命中哪个就用哪个，都不命中用第一个。
      // 第一个是 en —— 由 l10n.yaml 的 preferred-supported-locales 钉住（否则字母序 ar 会排第一）。
      // ≈ iOS 工程里勾选的 Localizations 语言集合。
      supportedLocales: AppLocalizations.supportedLocales,
      // locale 非 null 时**覆盖**系统语言（≈ 给 App 单独设了 AppleLanguages）。
      // 文字方向不用手动设：Localizations 会按语言自动提供 Directionality，
      // ar 下整棵树就是 TextDirection.rtl —— Row 从右往左排、EdgeInsetsDirectional 的 start 在右边。
      locale: userLocale,

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
