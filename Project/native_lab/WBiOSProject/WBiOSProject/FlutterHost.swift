import Flutter
import FlutterPluginRegistrant
import SwiftUI
import UIKit

/// 宿主 ↔ 模块的通道名（与 Dart 侧 host_bridge.dart 逐字符一致）。
let kHostChannelName = "com.wenbo.add_to_app/host"

/// 把宿主通道挂到【某个引擎】的 messenger 上，并返回它。
///
/// ★★ 本课最容易踩空的认知：**MethodChannel 是绑在"引擎"上的，不是全局的**。
///   同一个 App 里若有两个引擎，就得各自挂一次；在 A 引擎上挂的 handler，
///   B 引擎里的 Dart 代码调不到（表现为 MissingPluginException 或调用石沉大海）。
///   所以下面冷启动、预热两条路各自都要挂。
@discardableResult
func attachHostChannel(
    to messenger: FlutterBinaryMessenger,
    onClose: @escaping () -> Void
) -> FlutterMethodChannel {
    let channel = FlutterMethodChannel(name: kHostChannelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
        switch call.method {
        case "getUserToken":
            // Flutter → 原生：模块要登录态。企业真实场景里这里读 Keychain。
            result("HOST-TOKEN-\(Int(Date().timeIntervalSince1970))")
        case "closePage":
            // Flutter → 原生：模块请宿主关掉自己。
            // ★ 为什么必须原生来关：那个页是原生 present 的，
            //   在 Flutter 路由栈里它是根页，Flutter 自己 pop 不掉。
            onClose()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    return channel
}

// ─────────────────────────────────────────────────────────────────────────────
// L8：冷启动方式打开 Flutter 页（最简接入，但有代价）
// ─────────────────────────────────────────────────────────────────────────────

/// SwiftUI 里怎么塞一个 UIKit 的 FlutterViewController？用 UIViewControllerRepresentable。
/// （FlutterViewController 是 UIKit 世界的东西，SwiftUI 必须靠这层桥接。）
///
/// ★ L8 版本：每次打开都新建 `FlutterViewController(project:nibName:bundle:)`——
///   它会【当场新建并启动一个引擎】。好处是代码最少；代价是首屏要等引擎起来
///   （Dart VM 启动 + 加载 App.framework），肉眼可见一段白屏。L9 用预热解决它。
struct ColdFlutterPage: UIViewControllerRepresentable {
    /// Flutter 请求关闭时回调给 SwiftUI（收起 fullScreenCover）。
    let onClose: () -> Void

    /// Coordinator 的职责：把这条冷引擎的通道【强引用住】。
    /// 不留引用的话通道会被释放，Dart 侧的调用就没人接了。
    final class Coordinator {
        var channel: FlutterMethodChannel?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> FlutterViewController {
        // project: nil → 用默认 Flutter 配置；不传 engine = 自己新建隐式引擎。
        let vc = FlutterViewController(project: nil, nibName: nil, bundle: nil)
        vc.modalPresentationStyle = .fullScreen
        // ★ 这条【新引擎】必须自己挂一次通道——预热引擎上挂的那条它用不了。
        //   （漏了这步的现象：页面里"要 token""关闭"两个按钮全哑火，用户被困在页面里。）
        context.coordinator.channel = attachHostChannel(to: vc.binaryMessenger, onClose: onClose)
        return vc
    }

    func updateUIViewController(_ uiViewController: FlutterViewController, context: Context) {}
}

// ─────────────────────────────────────────────────────────────────────────────
// L9：预热引擎 + 双向通信 + 路由协调
// ─────────────────────────────────────────────────────────────────────────────

/// 宿主侧的引擎管家（单例）。
/// ★ 这是 add-to-app 工程化的核心：**引擎的生命周期由原生宿主掌管**，
///   不再是"打开页面才启动、关掉页面就销毁"。
///
/// 对照 L0 讲的引擎模型：Flutter App 里引擎随 App 起；这里引擎是我们主动
/// `run()` 起来并【常驻】的，FlutterViewController 只是它的一个"显示窗口"。
final class FlutterHostEngine {
    static let shared = FlutterHostEngine()

    /// 常驻引擎。App 启动就 run，页面打开时直接复用 → 秒开，没有 L8 那段白屏。
    let engine = FlutterEngine(name: "wb.host.engine")

    /// 挂在常驻引擎上的通道。页面来来去去，它始终活着。
    private var channel: FlutterMethodChannel?

    /// Flutter 请求关页面时宿主要做的事（由打开页面的一方注入）。
    var onCloseRequested: (() -> Void)?

    /// 是否已预热。引擎重复 run() 会出问题，用它守卫。
    private var isWarmedUp = false

    private init() {}

    /// App 启动时调用：预热引擎 + 挂通道。
    func warmUp() {
        guard !isWarmedUp else { return }
        isWarmedUp = true
        // ① 启动引擎（跑 module 的 main.dart）。这一步是耗时大头，提前做掉。
        engine.run()
        // ② 注册插件：模块里若用了 Flutter 插件，必须靠它注册到这个引擎上。
        //    （对照 L7：Flutter App 里这行在 AppDelegate；这里换成我们自己的引擎。）
        GeneratedPluginRegistrant.register(with: engine)
        // ③ 挂通道。binaryMessenger 用【引擎的】——通道要跟着引擎活。
        channel = attachHostChannel(to: engine.binaryMessenger) { [weak self] in
            self?.onCloseRequested?()
        }
    }

    /// 原生 → Flutter：宿主主动问模块"你现在什么状态"（反向调用）。
    func queryModuleState(completion: @escaping (String) -> Void) {
        channel?.invokeMethod("getPageState", arguments: nil) { value in
            if let text = value as? String {
                completion(text)
            } else if value is FlutterError {
                completion("模块返回错误")
            } else {
                completion("模块未应答（页面可能还没起来）")
            }
        }
    }

    /// L9 路由协调：告诉模块"现在显示哪一页"。
    ///
    /// ★★ 这里有个真会踩的坑：
    ///   `engine.navigationChannel.invokeMethod("setInitialRoute", ...)`
    ///   **只对还没 run() 的引擎有效**。我们的引擎在 App 启动时就预热跑起来了，
    ///   Dart 侧 MaterialApp 早已按 initialRoute 建好 widget 树——这时再 setInitialRoute
    ///   只是改了个没人再读的值，页面纹丝不动（现象：点 /detail 打开的还是首页）。
    ///
    ///   所以【热引擎】换页必须走自己的通道，让 Dart 侧真正去 Navigator 上跳转。
    ///   （冷引擎 = 打开页面才 run 的那种，才用 setInitialRoute。）
    func setRoute(_ route: String) {
        channel?.invokeMethod("setRoute", arguments: route)
    }
}

/// L9 版页面：复用预热好的常驻引擎（对照 ColdFlutterPage 的每次新建）。
struct WarmFlutterPage: UIViewControllerRepresentable {
    /// 宿主指定模块打开哪一页（'/' 或 '/detail'）。
    let route: String
    /// Flutter 请求关闭时回调给 SwiftUI（收起 fullScreenCover）。
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> FlutterViewController {
        let host = FlutterHostEngine.shared
        host.onCloseRequested = onClose
        host.setRoute(route) // 先定路由，再显示
        // engine: 传入常驻引擎 → 不新建、直接复用（这就是"秒开"的来源）。
        let vc = FlutterViewController(engine: host.engine, nibName: nil, bundle: nil)
        vc.modalPresentationStyle = .fullScreen
        return vc
    }

    func updateUIViewController(_ uiViewController: FlutterViewController, context: Context) {}
}
