import 'dart:async';

import 'messages.g.dart';

/// L5 设备信息桥（Pigeon 版）。对照 L1 的手写 DeviceInfoBridge：
/// - L1：手写 `MethodChannel('com.wenbo.native_lab/device_info')` + `invokeMethod('...')`
///   + 手拆返回的 Map 塞进自己写的 DeviceInfo 模型。
/// - L5：直接调生成的 `DeviceInfoHostApi().getDeviceInfo()`，返回生成的强类型
///   `DeviceInfoData`——channel 名、codec、Map 拆装全没了，交给生成代码。
///
/// 这层薄封装做两件事：
///  ① 持有生成的 HostApi 调用端（构造函数可注入，测试传 fake 子类 = pigeon 27 推荐的测法）；
///  ② 实现生成的 `DeviceEventFlutterApi` 接收端，把原生回推的电量事件转成 Stream
///     （对照 L3 的 EventChannel 用法，但事件是强类型 BatteryInfo，不用手拆 Map）。
class DeviceInfoPigeonBridge implements DeviceEventFlutterApi {
  DeviceInfoPigeonBridge({DeviceInfoHostApi? hostApi})
      : _host = hostApi ?? DeviceInfoHostApi() {
    // 注册"我"为反向回调的接收者：原生每调一次 onBatteryChanged，就进本类的同名方法。
    // 对照 L3 的 receiveBroadcastStream——都是"把原生的推送接到 Dart 这头"。
    DeviceEventFlutterApi.setUp(this);
  }

  final DeviceInfoHostApi _host;
  final StreamController<BatteryInfo> _battery =
      StreamController<BatteryInfo>.broadcast();

  /// Flutter→原生：取设备信息（生成方法，编译期类型安全）。
  Future<DeviceInfoData> getDeviceInfo() => _host.getDeviceInfo();

  /// 开/停电量订阅（对照 L3 onListen/onCancel，但走普通方法调用）。
  Future<void> startBatteryUpdates() => _host.startBatteryUpdates();
  Future<void> stopBatteryUpdates() => _host.stopBatteryUpdates();

  /// 原生回推的电量事件流（对照 L3 的 statusStream）。
  Stream<BatteryInfo> get batteryStream => _battery.stream;

  /// 生成接口的回调实现——原生每调一次 onBatteryChanged，就把强类型对象转进流里。
  @override
  void onBatteryChanged(BatteryInfo info) => _battery.add(info);

  /// 页面 dispose 时调用：摘掉反向接收端 + 关流（对照 L3 的 onCancel 清理）。
  void dispose() {
    DeviceEventFlutterApi.setUp(null);
    _battery.close();
  }
}
