import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_info.dart';

/// L1 设备信息桥（Dart 侧）。
/// iOS 类比：可以把 MethodChannel 想成一条命名的 XPC/消息通道——
/// 两端约好频道名和方法名（字符串），中间走二进制编解码（StandardMethodCodec）。
class DeviceInfoBridge {
  DeviceInfoBridge._(); // 纯静态入口，不给实例化（API 设计的取舍 L7 再展开）

  /// 频道名：反域名 + 功能名，Dart/Swift/Kotlin 三处必须逐字符一致。
  /// 这就是手写 channel 的"魔法字符串"痛点，L5 用 Pigeon 消灭它。
  @visibleForTesting
  static const MethodChannel channel = MethodChannel(
    'com.wenbo.native_lab/device_info',
  );

  /// 拉一次设备信息。
  /// invokeMapMethod 比 invokeMethod 多做一步 Map 的类型收窄
  /// （原生传来的其实是 `Map<Object?, Object?>`）。
  static Future<DeviceInfo> fetchDeviceInfo() async {
    final map = await channel.invokeMapMethod<String, Object?>('getDeviceInfo');
    if (map == null) {
      // 原生 result(nil) 的场景：给出可定位的错误而不是空指针崩溃。
      throw PlatformException(code: 'NULL_RESULT', message: '原生侧返回了空数据');
    }
    return DeviceInfo.fromMap(map);
  }

  /// 电池电量（0-100）。原生侧拿不到时会 result.error(UNAVAILABLE)，
  /// 在 Dart 这边表现为 PlatformException——调用方自己决定怎么兜底。
  static Future<int> fetchBatteryLevel() async {
    final level = await channel.invokeMethod<int>('getBatteryLevel');
    return level ?? -1;
  }

  // 系统开机时长秒数
  static Future<double> fetchUptime() async {
    final time = await channel.invokeMethod<double>("getSystemUpTime");
    return time ?? 0;
  }
}
