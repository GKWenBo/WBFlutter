import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'nl_device_kit_platform_interface.dart';
import 'src/device_info.dart';

/// 默认平台实现：走一条插件专属 channel `nl_device_kit`（独立于 L1 的手写 channel）。
/// 对照 L1 的 DeviceInfoBridge——同样是 invokeMethod + 收 Map，只是现在住在插件里，
/// 原生端由 GeneratedPluginRegistrant 自动注册（不再手写注册）。
class MethodChannelNlDeviceKit extends NlDeviceKitPlatform {
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('nl_device_kit');

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    final map = await methodChannel.invokeMapMethod<String, Object?>('getDeviceInfo');
    if (map == null) {
      throw PlatformException(code: 'NULL_RESULT', message: '原生侧返回了空数据');
    }
    return DeviceInfo.fromMap(map);
  }

  @override
  Future<int> getBatteryLevel() async {
    final level = await methodChannel.invokeMethod<int>('getBatteryLevel');
    return level ?? -1;
  }

  @override
  Future<double> getUptime() async {
    final time = await methodChannel.invokeMethod<double>('getSystemUpTime');
    return time ?? 0;
  }
}
