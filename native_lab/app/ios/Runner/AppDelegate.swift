import Flutter
import Network
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
    // 第二条 channel 并列注册：一个 App 挂多条 channel 靠名字区分，互不干扰。
    AnalyticsBridge.register(messenger: engineBridge.applicationRegistrar.messenger())
    // 第三条：EventChannel（网络状态推流）。
    NetworkBridge.register(messenger: engineBridge.applicationRegistrar.messenger())
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

/// L2 埋点桥（原生侧）。内存 buffer 模拟一个统计 SDK——
/// 真实场景这里换成 SDK 的 track()/logEvent() 调用。
enum AnalyticsBridge {
  // 模拟统计 SDK 的事件缓存。value 用 Any 才能装下 Dart 那边的混合类型。
  private static var buffer: [[String: Any]] = []

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.wenbo.native_lab/analytics", // 与 Dart 逐字符一致
      binaryMessenger: messenger)
    channel.setMethodCallHandler(handle)
  }

  private static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "logEvent":
      // Dart 的 Map<String,Object?> 经 StandardMessageCodec 解成 NSDictionary
      // → [String: Any]。数字统一是 NSNumber：取值时 .intValue/.doubleValue。
      guard let map = call.arguments as? [String: Any] else {
        result(FlutterError(code: "BAD_ARGS", message: "logEvent 期望 Map", details: nil))
        return
      }
      buffer.append(map)
      result(buffer.count) // 自增序号；Int 会被编码回 Dart 的 int
    case "logBatch":
      // 顶层参数是数组：Dart List<Map> → NSArray → [[String: Any]]。
      guard let list = call.arguments as? [[String: Any]] else {
        result(FlutterError(code: "BAD_ARGS", message: "logBatch 期望 List<Map>", details: nil))
        return
      }
      buffer.append(contentsOf: list)
      result(buffer.count) // 累加后的新总数
    case "fetchLoggedEvents":
      result(buffer) // [[String:Any]] → Dart List<Map>
    case "uploadRawLog":
      // 二进制：Dart Uint8List → FlutterStandardTypedData，.data 是 Data。
      guard let typed = call.arguments as? FlutterStandardTypedData else {
        result(FlutterError(code: "BAD_ARGS", message: "uploadRawLog 期望二进制", details: nil))
        return
      }
      result(typed.data.count)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// L3 网络状态桥（原生侧）。EventChannel 的原生端 = 一个 FlutterStreamHandler。
enum NetworkBridge {
  // 保持强引用：StreamHandler 持有 NWPathMonitor，别让它被释放（handler 被回收就收不到事件了）。
  private static var handler: NetworkStatusStreamHandler?

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterEventChannel(
      name: "com.wenbo.native_lab/network_status", // 三端逐字符一致
      binaryMessenger: messenger)
    let h = NetworkStatusStreamHandler()
    channel.setStreamHandler(h)
    handler = h
  }
}

/// 订阅生命周期对照 iOS：onListen ≈ addObserver / Combine sink，
/// onCancel ≈ removeObserver / AnyCancellable.cancel()。
final class NetworkStatusStreamHandler: NSObject, FlutterStreamHandler {
  // ⚠️ NWPathMonitor 一旦 cancel() 就报废、不能重启——所以不能复用同一实例，
  // 必须每次 onListen 新建（否则第二次订阅拿到的是死 monitor，永不回调 → 页面卡 loading）。
  private var monitor: NWPathMonitor?
  private let queue = DispatchQueue(label: "com.wenbo.native_lab.netmonitor")

  // Dart 侧一 listen，这里就被调用：新建 monitor，拿到 sink，开始把事件往里推。
  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    let m = NWPathMonitor()
    m.pathUpdateHandler = { path in
      let type: String
      let level: Int
      if path.status == .satisfied {
        type = path.usesInterfaceType(.wifi) ? "wifi" : "cellular"
        level = 3 // NWPath 拿不到真实信号强度，先占位满格（练习重点是 Map 编解码）
      } else {
        type = "none"
        level = 0
      }
      // L3 课后练习：从推 String 升级成推 Map——StandardMessageCodec 里
      // 流事件也能是 Map/List，编解码规则和 L2 的方法参数完全一样。
      // NWPathMonitor 回调在后台队列，事件必须回主线程投递给 sink（同 L1 规矩）。
      DispatchQueue.main.async { events(["type": type, "level": level]) }
    }
    m.start(queue: queue)
    monitor = m
    return nil
  }

  // Dart 侧取消订阅（StreamBuilder dispose）：cancel 当前 monitor 并丢弃，
  // 下次 onListen 会新建一个（cancel 过的不能复用）。
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    monitor?.cancel()
    monitor = nil
    return nil
  }
}
