import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    // MaterialApp.router：把导航交给 go_router 接管（从 M0 的 home: 升级而来）。
    return MaterialApp.router(
      title: 'WanShop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6F00)),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
