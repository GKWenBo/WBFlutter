import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // 应用级 channel 的官方注册口：applicationRegistrar 提供 binaryMessenger。
    // （插件走 pluginRegistry，应用自己的桥走这里——头文件注释原话就是
    //  "application-level method channels"。）
    DeviceInfoBridge.register(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// L1 设备信息桥（原生侧）。
/// 暂与 AppDelegate 同文件：往 Runner 加新 .swift 要动 pbxproj，
/// L7 抽成插件时它会搬进独立工程。用无 case 的 enum 当命名空间，防误实例化。
enum DeviceInfoBridge {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.wenbo.native_lab/device_info", // 与 Dart 侧逐字符一致
      binaryMessenger: messenger)
    channel.setMethodCallHandler(handle)
  }

  private static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // 这个回调跑在 Platform 线程 == iOS 主线程（L0 的线程模型落地了）。
    switch call.method {
    case "getDeviceInfo":
      let device = UIDevice.current
      let appVersion =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
      // 直接 result(字典)：StandardMethodCodec 自动把 Dictionary/String
      // 编解码成 Dart 的 Map/String（类型映射表 L2 展开）。
      result([
        "model": device.model,
        "systemName": device.systemName,
        "systemVersion": device.systemVersion,
        "appVersion": appVersion,
      ])
    case "getBatteryLevel":
      let device = UIDevice.current
      device.isBatteryMonitoringEnabled = true
      let level = device.batteryLevel
      if level < 0 {
        // 拿不到就明说（模拟器没有电池，batteryLevel 恒为 -1）——
        // 企业规矩：给 Dart 侧结构化错误码，不要静默塞假数据。
        result(FlutterError(
          code: "UNAVAILABLE",
          message: "拿不到电量（模拟器没有电池）",
          details: nil))
      } else {
        result(Int(level * 100))
      }
    case "getSystemUpTime":
        result(ProcessInfo.processInfo.systemUptime)
    default:
      // 方法名对不上：Dart 侧收到 MissingPluginException 的近亲——
      // FlutterMethodNotImplemented，防止两端方法清单悄悄漂移。
      result(FlutterMethodNotImplemented)
    }
  }
}
