import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'nl_device_kit_method_channel.dart';
import 'src/device_info.dart';

/// 插件能力的【抽象接口】。为什么多这一层？为"同一 API、多种实现"留缝——
/// 换平台、换后端、或测试里塞 mock，都只替换 instance，公开 API 不变。
/// 这就是"联邦插件"的接缝（完整联邦会把它单独拆成一个包）。
abstract class NlDeviceKitPlatform extends PlatformInterface {
  NlDeviceKitPlatform() : super(token: _token);

  static final Object _token = Object();
  static NlDeviceKitPlatform _instance = MethodChannelNlDeviceKit();

  /// 默认实现是 MethodChannel 版；测试可换成 mock（见 test）。
  static NlDeviceKitPlatform get instance => _instance;
  static set instance(NlDeviceKitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token); // 防止外部乱塞非法实现
    _instance = instance;
  }

  Future<DeviceInfo> getDeviceInfo() => throw UnimplementedError();
  Future<int> getBatteryLevel() => throw UnimplementedError();
  Future<double> getUptime() => throw UnimplementedError();
}
