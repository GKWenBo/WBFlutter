import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../features/settings/api.dart';
import '../l10n/app_localizations.dart';
import 'router/app_router.dart';

/// 整个 App 的根 Widget。
/// 角色 ≈ iOS 的 AppDelegate/SceneDelegate + UIWindow：装配标题、主题、路由。
///
/// 因为要 ref.watch(routerProvider)，所以要能访问 Riverpod 的 ref。
/// M12 国际化进阶起是 ConsumerStatefulWidget：要在 initState 里"按住"首帧（见下）。
class WanShopApp extends ConsumerStatefulWidget {
  const WanShopApp({super.key});

  @override
  ConsumerState<WanShopApp> createState() => _WanShopAppState();
}

class _WanShopAppState extends ConsumerState<WanShopApp> {
  @override
  void initState() {
    super.initState();
    // M12 国际化进阶：冷启动时语言偏好要异步读盘，读完之前 locale 是 null（= 系统语言）。
    // 如果直接出首帧：手机是英文、用户在 App 里选了阿语 → 每次启动先闪一帧英文 LTR，
    // 读完后整个界面再镜像成阿语 RTL。
    //
    // deferFirstFrame：告诉引擎"先别把画面送上屏"，原生启动图（LaunchScreen）会一直留着，
    // 等偏好读完 allowFirstFrame 再出第一帧——用户看到的第一帧就是正确语言。
    // 这正是 Flutter 自己的 Localizations 组件等异步翻译加载时用的机制；
    // 比"在 main() 里 await 预读再 override"好在 main.dart 保持极薄、读盘逻辑仍在 provider 里。
    // ≈ iOS 里让启动图多停留到首屏数据就绪，而不是先显示一个错误状态再刷新。
    final binding = WidgetsBinding.instance..deferFirstFrame();
    ref
        .read(appLocaleProvider.future)
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        // 无论成功失败都必须放行，否则 App 永远停在启动图。
        .whenComplete(binding.allowFirstFrame);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    // M12：标题不再写死，跟着当前 Flavor 走（dev 会显示 "WanShop Dev"）。
    final env = AppEnv.current;
    // M12 国际化进阶：用户在 App 内手选的语言；null = 跟随系统。
    // 读盘期间也是 null，但那几帧被 initState 里的 deferFirstFrame 挡住了，不会上屏。
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
