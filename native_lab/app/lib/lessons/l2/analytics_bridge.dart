import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'analytics_event.dart';

/// L2 埋点桥（Dart 侧）。与 L1 的 DeviceInfoBridge 同构，
/// 但这次参数/返回都是复杂结构，重点在 StandardMessageCodec 怎么搬运它们。
class AnalyticsBridge {
  AnalyticsBridge._();

  /// 第二条 channel（L1 是 device_info）。同一个 App 可以挂多条，
  /// 靠名字区分；原生侧要并列注册，别互相覆盖。
  @visibleForTesting
  static const MethodChannel channel = MethodChannel(
    'com.wenbo.native_lab/analytics',
  );

  /// 上报一个事件。invokeMethod 的第二参 = 传给原生的参数，
  /// 这里是一个嵌套 Map，codec 会递归编码每一层。原生回自增序号。
  static Future<int> logEvent(AnalyticsEvent event) async {
    final seq = await channel.invokeMethod<int>('logEvent', event.toMap());
    return seq ?? -1;
  }

  /// 把原生缓存的所有事件拉回来。invokeListMethod 先把顶层 `List<Object?>` 收窄；
  /// 每个元素仍是 `Map<Object?,Object?>`，再各自 cast + fromMap。
  static Future<List<AnalyticsEvent>> fetchLoggedEvents() async {
    final list = await channel.invokeListMethod<Object?>('fetchLoggedEvents');
    if (list == null) return const [];
    return list
        .map((e) => AnalyticsEvent.fromMap((e as Map).cast<String, Object?>()))
        .toList();
  }

  /// 批量上报：一次把多条事件灌下去，减少过桥次数（真实 SDK 常这么做）。
  /// 顶层参数这次是 `List<Map>`——codec 顶层就支持 List，注意和 logEvent 的 Map 参数区别。
  static Future<int> logBatch(List<AnalyticsEvent> events) async {
    final total = await channel.invokeMethod<int>(
      'logBatch',
      events.map((e) => e.toMap()).toList(),
    );
    return total ?? -1;
  }

  /// 上传一段二进制日志。Uint8List 走 codec 的 typed-data 分支，
  /// 零拷贝、不 base64——传字节流（缩略图/protobuf）就该用它。原生回收到的字节数。
  static Future<int> uploadRawLog(Uint8List bytes) async {
    final n = await channel.invokeMethod<int>('uploadRawLog', bytes);
    return n ?? 0;
  }
}
