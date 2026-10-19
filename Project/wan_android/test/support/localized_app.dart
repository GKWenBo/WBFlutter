import 'package:flutter/material.dart';
import 'package:wan_android/l10n/app_localizations.dart';

/// 测试用的"带国际化"宿主 App。
///
/// 为什么需要：页面里的文案都改成了 `AppLocalizations.of(context)`，
/// 裸的 `MaterialApp(home: Page())` 没装 delegate，of(context) 找不到实例会直接抛异常
/// （l10n.yaml 里 nullable-getter: false，取不到就是 null check 失败）。
///
/// 默认用中文：现有用例的断言写的是中文文案（find.text('加入购物车')），
/// 固定语言让断言不受跑测试那台机器的系统语言影响（flutter test 默认 en-US）。
/// ≈ XCUITest 里用 launchArguments 传 -AppleLanguages (zh-Hans)。
///
/// 测阿语/德语时传 locale，例如 `localizedApp(page, locale: const Locale('ar'))`
/// —— 传 ar 时 Directionality 自动变成 rtl，可以顺带验证镜像布局。
Widget localizedApp(Widget home, {Locale locale = const Locale('zh')}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}
