import 'nl_device_kit_platform_interface.dart';
import 'src/device_info.dart';

export 'src/device_info.dart'; // 消费方 import 一个库即可拿到 DeviceInfo

/// 插件对外的门面：消费方只认这个类，不关心底层是 channel 还是别的实现。
/// 三方法都委托给 NlDeviceKitPlatform.instance（默认 MethodChannel 版）。
class NlDeviceKit {
  Future<DeviceInfo> getDeviceInfo() =>
      NlDeviceKitPlatform.instance.getDeviceInfo();
  Future<int> getBatteryLevel() =>
      NlDeviceKitPlatform.instance.getBatteryLevel();
  Future<double> getUptime() => NlDeviceKitPlatform.instance.getUptime();
  Future<String> getDeviceModelName() =>
      NlDeviceKitPlatform.instance.getDeviceModelName();
}
