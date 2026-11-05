// =============================================================================
// 自定义页面转场 —— PageRouteBuilder
//
// 默认：MaterialPageRoute 在 iOS 上自动用右滑进入 + 侧滑返回（Cupertino 风格），Android 上是缩放淡入。
// 自定义：PageRouteBuilder(pageBuilder: 页面, transitionsBuilder: 怎么动)
//   transitionsBuilder(context, animation, secondaryAnimation, child)
//     animation          ：新页面进入的进度 0→1（pop 时 1→0）
//     secondaryAnimation ：当本页面被"别的页面盖住"时的进度，用于做旧页面的联动退场
//
// iOS 对应：UIViewControllerTransitioningDelegate + UIViewControllerAnimatedTransitioning；
//          modalTransitionStyle = .crossDissolve 之类的预设。
//
// 坑：自定义 PageRouteBuilder 默认没有 iOS 的侧滑返回手势；要侧滑返回用 CupertinoPageRoute。
// =============================================================================

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../widgets/demo_scaffold.dart';

/// 通用的自定义路由：传入一个 transitionsBuilder 即可复用。
Route<void> _buildRoute(String title, RouteTransitionsBuilder transitionsBuilder) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 500),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) => _TargetPage(title: title),
    transitionsBuilder: transitionsBuilder,
  );
}

class PageRouteDemo extends StatelessWidget {
  const PageRouteDemo({super.key});

  @override
  Widget build(BuildContext context) {
    // 每个条目：名称 + 生成 Route 的函数
    final routes = <String, Route<void> Function()>{
      // 1. 淡入淡出 ≈ .crossDissolve
      '淡入淡出 Fade': () => _buildRoute(
            '淡入淡出',
            (context, animation, secondary, child) => FadeTransition(opacity: animation, child: child),
          ),

      // 2. 从底部滑入 ≈ present 模态
      '底部滑入 Slide Up': () => _buildRoute(
            '底部滑入',
            (context, animation, secondary, child) => SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),

      // 3. 缩放 + 淡入
      '缩放 Scale + Fade': () => _buildRoute(
            '缩放淡入',
            (context, animation, secondary, child) {
              final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1).animate(curved),
                  child: child,
                ),
              );
            },
          ),

      // 4. 旋转进入（演示可以任意组合）
      '旋转 Rotation': () => _buildRoute(
            '旋转进入',
            (context, animation, secondary, child) => RotationTransition(
              turns: Tween<double>(begin: 0.5, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: ScaleTransition(scale: animation, child: child),
            ),
          ),

      // 5. 对照组：系统 iOS 风格，自带侧滑返回
      'CupertinoPageRoute（系统 iOS 风格）': () => CupertinoPageRoute<void>(
            builder: (_) => const _TargetPage(title: 'Cupertino 风格'),
          ),

      // 6. 对照组：全屏模态，从下往上 ≈ modalPresentationStyle = .fullScreen
      'fullscreenDialog（模态）': () => MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => const _TargetPage(title: '全屏模态'),
          ),
    };

    return DemoScaffold(
      title: '自定义页面转场',
      iosAnalogy: '≈ UIViewControllerAnimatedTransitioning / modalTransitionStyle',
      tips: const [
        'PageRouteBuilder 的 transitionsBuilder 决定页面怎么进出',
        'animation 管"我进来"，secondaryAnimation 管"我被盖住"',
        '自定义路由默认没有侧滑返回，需要时用 CupertinoPageRoute',
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in routes.entries)
            Card(
              child: ListTile(
                title: Text(entry.key),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => Navigator.of(context).push(entry.value()),
              ),
            ),
        ],
      ),
    );
  }
}

class _TargetPage extends StatelessWidget {
  const _TargetPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('返回（看反向动画）'),
        ),
      ),
    );
  }
}
