// L5 Pigeon 契约：本课唯一手写的"源头"。写完跑
//   dart run pigeon --input pigeons/device_info_api.dart
// 生成三端胶水（Dart / Swift / Kotlin）+ 一份测试桩。
//
// 这个文件本身【不参与运行】——它只是"给代码生成器看的规格说明"。
// 对照 iOS：你不会手写 URLSession 的收发样板，而是描述接口让工具/库产出；
// 这里描述 channel 契约（有哪些方法、参数/返回是什么类型），让 Pigeon 产出：
//   · Dart 侧：可直接调用的 DeviceInfoHostApi()、强类型数据类、私有 channel + codec
//   · 原生侧：要你实现的协议/接口 + 一行 setUp 挂载
// 前四课这些全靠手写（channel 名字符串、Map 手拼手拆、类型运行期才崩），本课交给生成。
import 'package:pigeon/pigeon.dart';

// @ConfigurePigeon：把"生成到哪、包名是什么"钉在契约文件里，
// 这样 `dart run pigeon --input <本文件>` 不用一长串命令行参数。
@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/lessons/l5/messages.g.dart',
  // 注：pigeon 27 已弃用生成 mock host（dartHostTestHandler），官方改推
  // "直接 fake 生成的 Dart API"。所以这里不再配 dartTestOut——测试见 bridge：
  // 构造函数可注入 DeviceInfoHostApi，测试传一个 fake 子类（依赖注入 + fake）。
  swiftOut: 'ios/Runner/DeviceInfoMessages.g.swift',
  kotlinOut:
      'android/app/src/main/kotlin/com/wenbo/native_lab/DeviceInfoMessages.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.wenbo.native_lab'),
  dartPackageName: 'native_lab',
))

/// 设备信息数据类。对照 L1 手写时靠 Map{'model': ..., 'systemVersion': ...} 手拼手拆，
/// 这里声明成"字段强类型的类"，Pigeon 生成三端等价的类 + 编解码。
/// 字段非空 → 三端生成的都是非空类型，少传一个字段编译期就报（手写 Map 做不到）。
class DeviceInfoData {
  DeviceInfoData({
    required this.model,
    required this.systemName,
    required this.systemVersion,
    required this.isPhysicalDevice,
    required this.batteryLevel, // 电量可能取不到 → 允许空
  });
  String model;
  String systemName;
  String systemVersion;
  bool isPhysicalDevice;
  int? batteryLevel; // 0–100；取不到时为 null
}

/// 电量信息。反向推流（FlutterApi）用的强类型载荷——对照 L3 EventChannel 推 Map 要手拆。
class BatteryInfo {
  BatteryInfo({required this.level, required this.isCharging});
  int level; // 0–100；-1 表示未知
  bool isCharging;
}

/// @HostApi：Flutter → 原生（对照 L1 的"Dart 调原生"）。
/// 这些方法名就是契约——生成后 Dart 侧 host.getDeviceInfo() 是真方法，
/// 改名/改签名两端一起编译报错（对照手写：invokeMethod('getDeviceInfo') 打错字运行期才崩）。
@HostApi()
abstract class DeviceInfoHostApi {
  /// @async：原生实现端拿到一个 completion/callback，可异步完成（演示 Pigeon 的异步契约）。
  @async
  DeviceInfoData getDeviceInfo();

  /// 开始/停止电量订阅——对照 L3 EventChannel 的 onListen/onCancel，
  /// 但这里是普通方法调用，真正的推流走下面的 FlutterApi。
  void startBatteryUpdates();
  void stopBatteryUpdates();
}

/// @FlutterApi：原生 → Flutter（反向）。生成后原生侧持有一个
/// DeviceEventFlutterApi 实例，调 onBatteryChanged(info) 就把强类型对象推给 Dart。
/// 这是 L3 EventChannel 的"类型安全版"：L3 事件是裸 Map 要手拆，这里是生成的 BatteryInfo。
@FlutterApi()
abstract class DeviceEventFlutterApi {
  void onBatteryChanged(BatteryInfo info);
}
