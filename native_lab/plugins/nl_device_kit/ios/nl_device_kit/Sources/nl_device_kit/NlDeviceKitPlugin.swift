import Flutter
import UIKit

/// 插件的 iOS 入口。对照前 6 课：那些桥在 AppDelegate 里【手写注册】；
/// 插件实现 FlutterPlugin，由 GeneratedPluginRegistrant 【自动】调 register(with:)——
/// 这是"插件"与"app 内嵌桥"最大的工程差异。
public class NlDeviceKitPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "nl_device_kit", binaryMessenger: registrar.messenger())
    let instance = NlDeviceKitPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getDeviceInfo":
      let device = UIDevice.current
      let appVersion =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
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
        result(FlutterError(code: "UNAVAILABLE", message: "拿不到电量（模拟器没有电池）", details: nil))
      } else {
        result(Int(level * 100))
      }
    case "getSystemUpTime":
      result(ProcessInfo.processInfo.systemUptime)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
