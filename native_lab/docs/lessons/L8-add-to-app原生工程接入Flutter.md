# L8 add-to-app：原生工程接入 Flutter

> 企业场景：前八课都是"**Flutter 工程**里怎么用原生能力"——Flutter 当家，`ios/Runner` 是它自带的壳。但真实世界里更常见的是**反过来**：公司有一个跑了五年的原生 App，几十万行 Swift，现在想用 Flutter 写新模块。没人会把老 App 推倒重来。这时要做的是 **add-to-app**：把 Flutter 作为一个**模块**接进已有的原生工程。本课就干这件事——从一个真实的 SwiftUI 原生 App（`WBiOSProject`）出发，把 Flutter module 用 CocoaPods 接进去，然后打开第一个 Flutter 页面。

**★ 角色对调是本课全部认知的起点**：L0–L7 里 Flutter 是宿主；从 L8 开始，**原生 App 才是宿主**，Flutter 是寄居的租客。谁先启动、谁管生命周期、谁决定路由、谁负责关页面——全都反过来。

## 一、本课要掌握什么

**1. flutter module 不是 Flutter App，也不是插件。**

| | Flutter App（L0–L6） | 插件（L7） | **module（L8）** |
|---|---|---|---|
| 谁是宿主 | Flutter | 都不是（被依赖的库） | **原生 App** |
| 产物 | 一个完整 App | 可复用的能力包 | 一段**可嵌入的 Flutter 内容** |
| 创建 | `flutter create` | `flutter create -t plugin` | `flutter create -t module` |
| 谁 import 谁 | Flutter 用原生 | App 用插件 | **原生 App 用 module** |

module 目录里有个隐藏的 `.ios/`——那是 Flutter 自动生成的"中转工程"，用来产出 `Flutter.framework` / `App.framework`。**你不要去改它**（每次构建会被重写），它只是给 CocoaPods 用的中间产物。

**2. ★ 接入的核心机关：podhelper.rb。**

原生工程的 `Podfile` 里就三件事：

```ruby
flutter_application_path = '../flutter_module'                       # ① module 在哪
load File.join(flutter_application_path, '.ios', 'Flutter', 'podhelper.rb')  # ② 加载 Flutter 的集成脚本
target 'WBiOSProject' do
  install_all_flutter_pods(flutter_application_path)                 # ③ 一行接管
end
```

`install_all_flutter_pods` 替你做了：把 `Flutter.framework`（引擎）、`App.framework`（你的 Dart 代码编译产物）、以及 module 依赖的**所有插件**都变成 Pod 依赖塞进来，并配好 Debug/Profile/Release 各自的产物路径 + 构建阶段脚本。

`pod install` 之后**必须改用 `.xcworkspace`**，`.xcodeproj` 单独打开是编不过的（这是 CocoaPods 的通例，不是 Flutter 特有）。

**3. SwiftUI 宿主怎么装下 FlutterViewController？**

`FlutterViewController` 是 **UIKit** 的东西，SwiftUI 里要靠 `UIViewControllerRepresentable` 桥接：

```swift
struct ColdFlutterPage: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> FlutterViewController {
        FlutterViewController(project: nil, nibName: nil, bundle: nil)  // 不传 engine = 当场新建
    }
    func updateUIViewController(_ vc: FlutterViewController, context: Context) {}
}
```

然后用 `.fullScreenCover` 整屏present。**对照 L4 的页面级混合**：那时是 Flutter 去 present 原生页；现在是原生去 present Flutter 页——同一套"页面级混合"思路，角色对调。

**4. ★ 冷启动的代价（这是 L9 存在的理由）。**

不传 `engine:` 的 `FlutterViewController` 会**当场新建并启动一个引擎**：启动 Dart VM、加载 `App.framework`、跑 `main()`、建 widget 树。这套流程有肉眼可见的耗时——点开按钮后会先看到**一段白屏**。

代码最少，但用户体感最差。L9 用**引擎预热**解决它。

**5. ★ MethodChannel 是绑在"引擎"上的，不是全局的。**

本课实测踩到的坑：冷启动路径每次都是**新引擎**，它和预热引擎是两个世界。在 A 引擎上挂的 channel handler，B 引擎里的 Dart **调不到**（表现：调用石沉大海 / `MissingPluginException`）。所以每条引擎都要各自挂一次通道：

```swift
// 冷启动路径：这条新引擎必须自己挂
context.coordinator.channel = attachHostChannel(to: vc.binaryMessenger, onClose: onClose)
```

漏了这步的现象很唬人：Flutter 页里"关闭"按钮点了没反应，**用户被困在页面里出不来**。

## 二、控件 / API 速查表

| API | 说明 | 坑 |
|---|---|---|
| `flutter create -t module` | 创建可嵌入模块 | 生成的 `.ios/` 是中间产物，别手改 |
| `podhelper.rb` + `install_all_flutter_pods` | Flutter 的 CocoaPods 集成脚本 | 路径写错则 `pod install` 直接失败 |
| `.xcworkspace` | pod 集成后的正确入口 | 继续用 `.xcodeproj` 必然编不过 |
| `FlutterViewController(project:nibName:bundle:)` | 自带引擎的 VC（冷启动） | 每次新建引擎 → 白屏 |
| `UIViewControllerRepresentable` | SwiftUI ↔ UIKit 桥 | Flutter 侧是 UIKit，SwiftUI 必须包一层 |
| `vc.binaryMessenger` | 该 VC 所属引擎的信使 | **通道要挂在对应引擎上** |
| `ENABLE_USER_SCRIPT_SANDBOXING` | Xcode 15+ 新工程默认 YES | **必须改 NO**，否则 Flutter 的 embed 脚本被沙箱拦住（见下） |

### 本课实际踩到的三个环境坑

1. **`ENABLE_USER_SCRIPT_SANDBOXING = YES`**（Xcode 15+ 新建工程的默认值）
   → 构建报 `Sandbox: rsync(xxx) deny(1) file-read-data ...`。
   Flutter 的 "Embed Flutter Build" 脚本要 rsync 产物进 .app，被沙箱拒了。**改成 NO**。
2. **CocoaPods 的 locale 坑**：`pod install` 报
   `Unicode Normalization not appropriate for ASCII-8BIT`。
   → 用 UTF-8 环境跑：`LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install`。
3. **Info.plist 提示 `NSBonjourServices` / `NSLocalNetworkUsageDescription` 取不到值**
   → Debug 构建时 Flutter 想配本地网络权限（真机热重载/调试器发现用）。模拟器上无害可忽略；要上真机调试再补这两个键。

## 三、代码地图

**Flutter 模块 `flutter_module/`（新增）**
- `lib/main.dart` — `ModuleApp`：路由表（`/`、`/detail`）+ 两个页面。
- `lib/host_bridge.dart` — 宿主桥：Flutter→原生（要 token、请求关闭）+ 原生→Flutter（查状态、切路由）。
- `test/host_bridge_test.dart` — 双向通信的 Dart 单测。

**原生宿主 `WBiOSProject/`（你手建的工程，本课改造）**
- `Podfile`（新增）— 三行接入机关。
- `WBiOSProject/FlutterHost.swift`（新增）— `attachHostChannel`（每引擎挂通道）、`ColdFlutterPage`（L8 冷启动）、`FlutterHostEngine` + `WarmFlutterPage`（L9）。
- `WBiOSProject/ContentView.swift`（改）— 原生首页，四个入口。
- `WBiOSProject/WBiOSProjectApp.swift`（改）— `@UIApplicationDelegateAdaptor` 挂 AppDelegate（L9 预热用）。
- `WBiOSProject.xcodeproj`（改）— `ENABLE_USER_SCRIPT_SANDBOXING` 改 NO。

## 四、测试怎么写

原生宿主工程没有 Flutter 的测试框架，所以**分层测**：

- **模块侧（Dart 单测）**：测通道协议本身——`getUserToken`/`closePage` 发出的 method call 是否正确；原生打进来的 `getPageState` 是否被正确应答（用真实 codec 编码消息喂给接收端）。
- **宿主侧（模拟器实跑）**：接入是否成功、页面是否打开、按钮是否有反应——这些跨了进程边界和构建系统，只能真跑。本课四条路径全部在 iPhone 模拟器上点过一遍。

## 五、iOS 专属说明（Android 侧概念差异）

L8/L9 是 iOS 专属场景（宿主就是 iOS 工程），Android 侧不实现，但概念一一对应：

| | iOS | Android |
|---|---|---|
| 集成方式 | CocoaPods（`podhelper.rb`） | Gradle（`include_flutter.groovy` 或 AAR） |
| 承载容器 | `FlutterViewController` | `FlutterActivity` / `FlutterFragment` |
| 引擎类 | `FlutterEngine` | `FlutterEngine`（同名） |
| 引擎缓存 | 自己持有单例 | `FlutterEngineCache`（官方提供） |
| 加进 SwiftUI/Compose | `UIViewControllerRepresentable` | `AndroidView` / 直接起 Activity |

## 六、自测清单

1. flutter module、Flutter App、Flutter 插件三者有什么区别？分别谁依赖谁？
2. `install_all_flutter_pods` 到底替你做了哪些事？为什么 `pod install` 之后必须改用 `.xcworkspace`？
3. module 里的 `.ios/` 目录是什么？能不能在里面改代码？为什么？
4. SwiftUI 宿主为什么不能直接写 `FlutterViewController`？要靠什么桥接？
5. 冷启动打开 Flutter 页时那段白屏是什么造成的？
6. 为什么冷启动路径必须**单独再挂一次** MethodChannel？漏了会出现什么现象？
7. 对照 L4 的页面级混合，L8 在"谁 present 谁"上有什么根本不同？

> 自测答案见 [自测答案/L8-自测答案.md](自测答案/L8-自测答案.md)。

## 七、课后练习

给宿主再加一个入口：**用 `UINavigationController` push 一个 Flutter 页**（而不是 `fullScreenCover` 整屏 present），观察：

1. Flutter 页上方会不会出现原生导航栏？两套导航（原生 NavigationStack + Flutter Navigator）同时存在时，返回手势归谁管？
2. 把 Flutter 页里的 `automaticallyImplyLeading: false` 去掉，看 Flutter 自己画的返回按钮点了会发生什么（提示：它 pop 的是 Flutter 的栈，不是原生的）。

这正是**混合栈**最常见的坑：两套路由各管各的，边界上要么手动协调、要么用 flutter_boost 这类框架统一。L9 会把"原生驱动路由"这一半做出来。
