import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'native_platform_view.dart';

/// L6 入口页：把原生视图嵌进 Flutter 页面（视图级混合）。
/// 对照 L4 页面级混合：L4 是"整屏交给原生 VC/Activity，结果回传后就退出"；
/// L6 是"原生视图作为一个 widget 长在 Flutter 布局里，和 Flutter 控件同屏共存"。
class L6PlatformViewPage extends StatefulWidget {
  const L6PlatformViewPage({super.key});

  @override
  State<L6PlatformViewPage> createState() => _L6PlatformViewPageState();
}

class _L6PlatformViewPageState extends State<L6PlatformViewPage> {
  NativeViewController? _controller; // 原生视图创建后才有（onCreated 回填）
  final bool _isAndroid = defaultTargetPlatform == TargetPlatform.android;

  // 创建参数按平台给：iOS 传地图初始区域，Android 传初始 URL。
  Map<String, dynamic> get _creationParams => _isAndroid
      ? const {'url': 'https://flutter.dev'}
      : const {'lat': 31.2304, 'lng': 121.4737, 'span': 0.2}; // 上海

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('L6 PlatformView 视图级混合')),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _isAndroid
                    ? '下方是嵌进来的【原生 WebView】。同一套 PlatformView 机制，'
                        'iOS 那端嵌的是真 MKMapView——嵌什么原生视图是各端自己的事。'
                    : '下方是嵌进来的【真 MKMapView】。它作为一个 widget 长在 Flutter '
                        '布局里，和上面的说明卡、下面的按钮同屏共存（对照 L4 的整屏接管）。',
              ),
            ),
          ),
          // 原生视图占据主要空间。Expanded 给它一个有界高度（PlatformView 需要确定尺寸）。
          Expanded(
            child: NativePlatformView(
              creationParams: _creationParams,
              onCreated: (c) => _controller = c,
            ),
          ),
          _ControlBar(isAndroid: _isAndroid, controllerOf: () => _controller),
        ],
      ),
    );
  }
}

/// 控制条：按平台显示对应按钮，点击走【每实例方法通道】驱动原生视图。
class _ControlBar extends StatelessWidget {
  const _ControlBar({required this.isAndroid, required this.controllerOf});

  final bool isAndroid;
  final NativeViewController? Function() controllerOf;

  @override
  Widget build(BuildContext context) {
    final buttons = isAndroid
        ? [
            FilledButton.tonal(
              onPressed: () => controllerOf()?.reload(),
              child: const Text('Reload'),
            ),
            FilledButton.tonal(
              onPressed: () => controllerOf()?.loadUrl('https://dart.dev'),
              child: const Text('换到 dart.dev'),
            ),
          ]
        : [
            FilledButton.tonal(
              onPressed: () => controllerOf()?.setMapType('standard'),
              child: const Text('标准'),
            ),
            FilledButton.tonal(
              onPressed: () => controllerOf()?.setMapType('satellite'),
              child: const Text('卫星'),
            ),
            FilledButton.tonal(
              onPressed: () => controllerOf()?.resetRegion(),
              child: const Text('回到初始点'),
            ),
          ];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(spacing: 12, runSpacing: 8, children: buttons),
    );
  }
}
