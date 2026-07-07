import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'network_status.dart';

/// L3 网络状态桥（Dart 侧）。第三条 channel，且是第一条 EventChannel。
/// 心智模型：EventChannel 就是"原生侧的一条 Stream"——
/// receiveBroadcastStream() 一订阅，原生的 onListen 就被触发开始推；
/// 取消订阅，原生的 onCancel 被触发去拆监听。
class NetworkBridge {
  NetworkBridge._();

  @visibleForTesting
  static const EventChannel channel = EventChannel(
    'com.wenbo.native_lab/network_status',
  );

  /// 订阅网络状态流。原生现在持续推 Map{'type','level'}（L3 课后练习升级），
  /// 这里 map 成强类型 NetworkInfo 交给 UI。
  /// broadcast = 多个监听者共享同一条原生流（对比 single-subscription）。
  static Stream<NetworkInfo> statusStream() {
    return channel.receiveBroadcastStream().map(
      (raw) => NetworkInfo.fromMap(raw as Map<Object?, Object?>?),
    );
  }
}
