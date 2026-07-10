import AVFoundation
import Flutter
import Network
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // L5 Pigeon：强引用住 host 实例（对照 NetworkBridge 强引用 StreamHandler）。
  // 它内部还持有反向的 DeviceEventFlutterApi，被回收就推不动电量事件了。
  private var deviceInfoPigeonHost: DeviceInfoPigeonHost?

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
    // 第四条：页面级混合——present 原生扫码页并回传结果。
    ScanBridge.register(messenger: engineBridge.applicationRegistrar.messenger())
    // 第五条：L5 Pigeon——用【生成的】Setup 挂载，不再手写 channel 名 / codec。
    // 对照上面 L1–L4 的 register：那些都是我们手写的 FlutterMethodChannel(name:)；
    // 这里 channel 名（dev.flutter.pigeon.native_lab.*）由生成代码管理。
    let messenger = engineBridge.applicationRegistrar.messenger()
    let pigeonHost = DeviceInfoPigeonHost(binaryMessenger: messenger)
    DeviceInfoHostApiSetup.setUp(binaryMessenger: messenger, api: pigeonHost)
    deviceInfoPigeonHost = pigeonHost
  }
}

/// L5 设备信息桥（原生侧，Pigeon 版）。对照 L1 的手写 DeviceInfoBridge：
/// L1 我们手写 FlutterMethodChannel + setMethodCallHandler + 手拼返回字典；
/// 这里【实现 Pigeon 生成的 DeviceInfoHostApi 协议】——方法签名、参数/返回类型
/// 都由生成代码定死，少实现一个方法 / 类型不对 → 编译报错（手写通道做不到）。
/// 继承 NSObject 是为了用 NotificationCenter 的 @objc selector 监听电量。
final class DeviceInfoPigeonHost: NSObject, DeviceInfoHostApi {
    func getBatteryInfo(completion: @escaping (Result<BatteryInfo, any Error>) -> Void) {
        let d = UIDevice.current
        // ⚠️ 必须先开电量监控，否则 batteryLevel 恒 -1、batteryState 为 .unknown。
        // getDeviceInfo 里有这句、这里当初漏了——真机上先点"读一次电量"就会永远显示未知。
        d.isBatteryMonitoringEnabled = true
        let info = BatteryInfo(
          level: d.batteryLevel < 0 ? -1 : Int64(d.batteryLevel * 100),
          isCharging: d.batteryState == .charging || d.batteryState == .full)
        completion(.success(info))
    }
    
  // 反向推流用：持有【生成的】FlutterApi 调用端（对照 L3 的 sink，但这是强类型方法）。
  private let flutterApi: DeviceEventFlutterApi
  private var observing = false

  init(binaryMessenger: FlutterBinaryMessenger) {
    self.flutterApi = DeviceEventFlutterApi(binaryMessenger: binaryMessenger)
    super.init()
  }

  // @async 契约 → 生成的是带 completion 的签名（对照 L1 handler 里的 result(...)）。
  func getDeviceInfo(completion: @escaping (Result<DeviceInfoData, Error>) -> Void) {
    let d = UIDevice.current
    d.isBatteryMonitoringEnabled = true
    // 模拟器电量恒为 -1；取不到就回 nil（契约里 batteryLevel 是可空的）。
    let level: Int64? = d.batteryLevel < 0 ? nil : Int64(d.batteryLevel * 100)
    // isPhysicalDevice：编译期区分模拟器 / 真机（Swift 官方写法）。
    #if targetEnvironment(simulator)
    let physical = false
    #else
    let physical = true
    #endif
    // 返回【生成的强类型 struct】，不是字典——对照 L1 的 result([...]) 手拼 Map。
    completion(.success(DeviceInfoData(
      model: d.model,
      systemName: d.systemName,
      systemVersion: d.systemVersion,
      isPhysicalDevice: physical,
      batteryLevel: level)))
  }

  func startBatteryUpdates() throws {
    guard !observing else { return }
    observing = true
    UIDevice.current.isBatteryMonitoringEnabled = true
    // 对照 L3：注册通知观察（≈ EventChannel 的 onListen）。电量值和充电状态各一个通知。
    NotificationCenter.default.addObserver(
      self, selector: #selector(batteryChanged),
      name: UIDevice.batteryLevelDidChangeNotification, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(batteryChanged),
      name: UIDevice.batteryStateDidChangeNotification, object: nil)
    batteryChanged() // 立即推一次当前值，别让 Dart 侧干等
  }

  func stopBatteryUpdates() throws {
    observing = false
    NotificationCenter.default.removeObserver(self) // ≈ EventChannel 的 onCancel
  }

  @objc private func batteryChanged() {
    let d = UIDevice.current
    let info = BatteryInfo(
      level: d.batteryLevel < 0 ? -1 : Int64(d.batteryLevel * 100),
      isCharging: d.batteryState == .charging || d.batteryState == .full)
    // 通知回调在主线程，直接调；生成的 FlutterApi 帮我们编码 + 过 channel 推给 Dart。
    // completion 里的错误一般忽略（Dart 侧没监听时会有 error，不影响）。
    flutterApi.onBatteryChanged(info: info) { _ in }
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

/// L4 扫码桥（原生侧）。页面级混合：present 一个原生 VC 接管整屏，
/// 把 FlutterResult 暂存，等用户扫完/取消再回。
/// ★ 与 L1/L2 的关键差异：result 不在 handler 里立刻回，而是"延迟"到用户操作后。
///   FlutterResult 只能调用一次——所以要单次在飞行守卫 + 回完置空。
enum ScanBridge {
  // 暂存那次延迟的 result。present 出去后 handler 就 return 了，真正的回值靠它。
  private static var pendingResult: FlutterResult?

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.wenbo.native_lab/scanner", // 三端逐字符一致
      binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "scan":
        // L4 课后练习：取出打开原生页时携带的入参 hint（Map 入参，编解码同 L2）。
        let hint = (call.arguments as? [String: Any])?["hint"] as? String
        handleScan(hint: hint, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func handleScan(hint: String?, result: @escaping FlutterResult) {
    // 上一次扫码还没回就直接拒，避免 pendingResult 被覆盖（result 只能调一次）。
    if pendingResult != nil {
      result(FlutterError(code: "ALREADY_SCANNING", message: "已在扫码中", details: nil))
      return
    }
    // 相机权限：真机扫码要开 AVCaptureSession，先拿权限。本课扫码页是模拟的，
    // 但权限这条线走真实流程（这就是本课的"运行时权限"知识点）。
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      presentScanner(hint: hint, result: result)
    case .notDetermined:
      // 首次：弹系统授权框。回调在任意线程，present 必须切回主线程。
      AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async {
          if granted {
            presentScanner(hint: hint, result: result)
          } else {
            result(FlutterError(code: "PERMISSION_DENIED", message: "相机权限被拒", details: nil))
          }
        }
      }
    default: // .denied / .restricted：用户之前拒过或被家长控制限制
      result(FlutterError(code: "PERMISSION_DENIED", message: "相机权限被拒", details: nil))
    }
  }

  private static func presentScanner(hint: String?, result: @escaping FlutterResult) {
    guard let top = topViewController() else {
      result(FlutterError(code: "NO_UI", message: "找不到可 present 的控制器", details: nil))
      return
    }
    pendingResult = result // 现在开始"延迟回值"，直到扫码页 dismiss
    let scanner = MockScannerViewController(hint: hint) { code in finish(with: code) }
    let nav = UINavigationController(rootViewController: scanner)
    nav.modalPresentationStyle = .fullScreen
    top.present(nav, animated: true)
  }

  // 回传出口：扫到 code(String) → Dart 得字符串（ScanSuccess）；取消(nil) → Dart 得 null（ScanCancelled）。
  private static func finish(with code: String?) {
    pendingResult?(code)
    pendingResult = nil // 置空，让下一次 scan 能进
  }

  // Flutter + Scene 世界里"从哪 present"：取前台 windowScene 的 rootVC 再顺到最顶层。
  private static func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .first { $0.activationState == .foregroundActive } as? UIWindowScene
    var top = scene?.keyWindow?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}

/// 模拟扫码页（原生 UIViewController）。真机上这里是 AVCaptureSession 预览 +
/// AVCaptureMetadataOutput 识别二维码；模拟器没相机，用预置按钮 + 输入框替代"扫到"，
/// 但 present/dismiss/回传这条页面级混合主线完全真实。
/// 注意 dismiss 的 completion 里才调 onFinish——先收掉原生页，再把结果回给 Flutter。
final class MockScannerViewController: UIViewController {
  private let onFinish: (String?) -> Void
  private let hint: String? // L4 课后练习：Flutter 打开原生页时带下来的提示语，用作标题
  private let field = UITextField()

  init(hint: String?, onFinish: @escaping (String?) -> Void) {
    self.hint = hint
    self.onFinish = onFinish
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) 未使用") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    title = hint ?? "模拟扫码（本机无相机）"
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))

    field.placeholder = "手动输入一个码"
    field.borderStyle = .roundedRect

    let preset1 = makeButton("扫到 SKU-10086") { [weak self] in self?.scanned("SKU-10086") }
    let preset2 = makeButton("扫到 COUPON-8") { [weak self] in self?.scanned("COUPON-8") }
    let confirm = makeButton("确认输入的码") { [weak self] in
      guard let self else { return }
      let text = self.field.text ?? ""
      self.scanned(text.isEmpty ? "EMPTY" : text)
    }

    let stack = UIStackView(arrangedSubviews: [field, preset1, preset2, confirm])
    stack.axis = .vertical
    stack.spacing = 16
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
    ])
  }

  @objc private func cancelTapped() {
    dismiss(animated: true) { [onFinish] in onFinish(nil) } // 取消 = nil
  }

  private func scanned(_ code: String) {
    dismiss(animated: true) { [onFinish] in onFinish(code) } // 扫到 = code
  }

  private func makeButton(_ title: String, _ action: @escaping () -> Void) -> UIButton {
    let b = UIButton(type: .system)
    b.setTitle(title, for: .normal)
    b.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
    b.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return b
  }
}
