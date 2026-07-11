import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// PlatformView 的类型标识：Dart 按它嵌入，两端 factory 按它注册（逐字符一致）。
const String kNativeViewType = 'com.wenbo.native_lab/native_view';

/// 每个原生视图【实例】的控制器。关键认知差异：L1–L5 是应用级单例 channel，
/// 这里每个实例一条 channel（用 onPlatformViewCreated 给的 viewId 区分），
/// 因为一个页面可能同时嵌多个同类原生视图，得能分别寻址。
class NativeViewController {
  NativeViewController(int viewId, {BinaryMessenger? messenger})
      : _channel = MethodChannel(
          'com.wenbo.native_lab/native_view_$viewId',
          const StandardMethodCodec(),
          messenger,
        );

  final MethodChannel _channel;

  // iOS 地图控制
  Future<void> setMapType(String type) =>
      _channel.invokeMethod('setMapType', type); // 'standard' | 'satellite'
  Future<void> resetRegion() => _channel.invokeMethod('resetRegion');

  // Android WebView 控制
  Future<void> reload() => _channel.invokeMethod('reload');
  Future<void> loadUrl(String url) => _channel.invokeMethod('loadUrl', url);
}

/// 嵌入原生视图的 widget：按平台分发到 UiKitView / AndroidView。
/// 机制两端一致（同一个 viewType、同一套 creationParams），
/// 但各端 factory 产出的原生视图不同（iOS=MKMapView，Android=WebView）。
class NativePlatformView extends StatelessWidget {
  const NativePlatformView({
    super.key,
    required this.creationParams,
    required this.onCreated,
  });

  /// 创建时一次性传给原生的初始状态（Dart→原生），走 StandardMessageCodec 编码。
  final Map<String, dynamic> creationParams;

  /// 原生视图创建完成回调：拿到 viewId → 造一个绑定该实例的控制器交给页面。
  final void Function(NativeViewController) onCreated;

  @override
  Widget build(BuildContext context) {
    const codec = StandardMessageCodec();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: kNativeViewType,
        creationParams: creationParams,
        creationParamsCodec: codec,
        onPlatformViewCreated: (id) => onCreated(NativeViewController(id)),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // 本课 WebView 只做加载+reload、无文本输入，普通 AndroidView（虚拟显示）够用；
      // 涉及键盘/输入等场景才需切 hybrid composition（PlatformViewLink 那套样板）。
      return AndroidView(
        viewType: kNativeViewType,
        creationParams: creationParams,
        creationParamsCodec: codec,
        onPlatformViewCreated: (id) => onCreated(NativeViewController(id)),
      );
    }
    return const Center(child: Text('该平台不支持原生视图嵌入'));
  }
}
