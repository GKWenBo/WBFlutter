import 'package:flutter/material.dart';

import 'main_scaffold.dart';

/// 整个 App 的根 Widget。
///
/// 角色 ≈ iOS 的 AppDelegate/SceneDelegate + UIWindow：
/// 负责"装配"全局配置——标题、主题、首页、（以后）路由表。
/// 它自身不持有会变的状态，所以是 StatelessWidget（纯函数式视图：给定输入 → 固定输出）。
class WanShopApp extends StatelessWidget {
  const WanShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp 是"应用容器"，内部已经帮你接好了导航栈、本地化、主题分发等基础设施。
    // 你几乎每个 App 的最外层都是它（或 iOS 风格的 CupertinoApp）。
    // 到 M5 接入 go_router 时，这里会从 MaterialApp(home:) 升级为 MaterialApp.router(...)。
    return MaterialApp(
      title: 'WanShop',
      debugShowCheckedModeBanner: false, // 去掉右上角那个红色 DEBUG 角标
      // ThemeData ≈ 全局 UIAppearance + 一整套设计规范。
      // 给一个电商常见的橙色"种子色"，Material 3 会据此自动生成协调的明/暗配色体系。
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6F00)),
        useMaterial3: true,
      ),
      home: const MainScaffold(), // 启动后展示的主框架（= rootViewController）
    );
  }
}
