import 'package:flutter/material.dart';

/// L0 入口页：把"原生工程解剖"的结论做成页内速查。
/// 本课没有任何 channel 代码——先认识地形，L1 才开始通信。
class L0AnatomyPage extends StatelessWidget {
  const L0AnatomyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('L0 原生工程解剖')),
      body: ListView(
        children: const [
          _SectionHeader('ios/ —— 一个完整的 Xcode 工程'),
          _AnatomyTile(
            path: 'Runner.xcworkspace',
            role: '用 Xcode 打开的入口（含 CocoaPods 依赖），和你平时的 workspace 一回事',
          ),
          _AnatomyTile(
            path: 'Runner/AppDelegate.swift',
            role: 'App 入口，继承 FlutterAppDelegate；插件在这里完成注册',
          ),
          _AnatomyTile(
            path: 'Runner/SceneDelegate.swift',
            role: '新模板已接 UIScene 生命周期，和你现在的原生工程一致',
          ),
          _AnatomyTile(
            path: 'Runner/Info.plist',
            role: '原封不动的 Info.plist，权限描述、显示名都在这改',
          ),
          _AnatomyTile(
            path: 'Flutter/Generated.xcconfig',
            role: 'flutter 工具生成的构建配置，把 Dart 产物接进 Xcode 构建',
          ),
          _SectionHeader('android/ —— 一个完整的 Gradle 工程'),
          _AnatomyTile(
            path: 'app/src/main/kotlin/.../MainActivity.kt',
            role: '继承 FlutterActivity，对应 iOS 侧的 FlutterViewController 宿主',
          ),
          _AnatomyTile(
            path: 'app/build.gradle.kts',
            role: '模块构建脚本，applicationId/签名/依赖，类比 project.pbxproj + Podfile',
          ),
          _AnatomyTile(
            path: 'app/src/main/AndroidManifest.xml',
            role: '类比 Info.plist：权限声明、App 显示名、入口 Activity',
          ),
          _SectionHeader('引擎与线程（L1 前必备概念）'),
          _AnatomyTile(
            path: 'FlutterEngine',
            role: 'Dart 代码的运行时。UI 线程跑 Dart，Platform 线程就是 iOS 主线程',
          ),
          _AnatomyTile(
            path: 'FlutterViewController',
            role: '把引擎渲染的内容装进 UIKit 的容器 VC，App 的 rootViewController 就是它',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _AnatomyTile extends StatelessWidget {
  const _AnatomyTile({required this.path, required this.role});
  final String path;
  final String role;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.description_outlined),
      title: Text(path),
      subtitle: Text(role),
    );
  }
}
