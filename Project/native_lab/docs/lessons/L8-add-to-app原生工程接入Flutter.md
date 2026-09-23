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

**6. ★ 两种集成方式：源码集成 vs 产物集成（企业里真正要做的选型）。**

本课用的 `podhelper.rb` 是**源码集成**：宿主工程构建时**当场编译 Flutter module**。它的隐含要求是——**每个 iOS 同事的机器上都要装 Flutter SDK、且版本一致**，CI 也要装。对一个几十人的原生团队来说，这经常是不可接受的。

另一条路是**产物集成**：由 Flutter 团队（或 CI）预先构建出**二进制产物**，原生同学像用普通三方库一样用它。

| | 源码集成（本课） | 产物集成 |
|---|---|---|
| iOS 做法 | `podhelper.rb` + `install_all_flutter_pods` | `flutter build ios-framework` → 产出 `Flutter.xcframework` / `App.xcframework` / 各插件 xcframework，走私有 pod 或直接嵌入 |
| Android 做法 | `include_flutter.groovy`（settings.gradle） | `flutter build aar` → 发到 maven 仓库，Gradle 按坐标依赖 |
| 原生同事要装 Flutter SDK 吗 | **要** | **不要** |
| Dart 改动的生效方式 | 重新构建即可 | 要 Flutter 侧**重新发一版产物**，原生升版本号 |
| 适合 | 混合团队、Flutter 改动频繁、人少 | 原生团队为主、Flutter 模块相对独立、要卡版本 |

**记住这个取舍点**——"你们 add-to-app 是怎么集成的"是这一课最常被追问的问题，能答出两条路和各自代价，比只会说 `pod install` 强得多。

**7. 调试：`flutter run` 在 add-to-app 里不好使，用 `flutter attach`。**

宿主是原生工程，启动入口在 Xcode（或 Android Studio），所以流程变成：

1. 用 **Xcode 跑起宿主 App**（Debug 配置）；
2. 在 module 目录下执行 `flutter attach`（工具会发现设备上跑着的 Dart VM 并连上）；
3. 之后**热重载、DevTools、日志**都照常可用。

真机调试时若提示 `NSBonjourServices` / `NSLocalNetworkUsageDescription`，就是这套发现机制需要本地网络权限——补上这两个 Info.plist 键即可（模拟器上可忽略）。

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
| `flutter build ios-framework` | 产出 `Flutter.xcframework`/`App.xcframework`/插件 xcframework | **产物集成**路线的入口（Android 对应 `flutter build aar`）；Dart 改了要重新发版 |
| `flutter attach` | 连上正在运行的宿主 App，恢复热重载/DevTools | add-to-app 里 `flutter run` 不适用，先用 Xcode 跑宿主再 attach |

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

## 八、面试高频题（附答案）

> 面试语境：**这是最能区分"做过真项目"和"写过 demo"的一课**。国内大厂的混合开发岗，八成会问 add-to-app；而且问法很实际——"你们老 App 是怎么把 Flutter 接进去的""包大了多少""原生同学要不要装 Flutter"。

**Q1. 什么是 add-to-app？它和 Flutter App、插件有什么区别？**

add-to-app 是**把 Flutter 作为一个模块接进已有的原生工程**，角色彻底对调：

| | Flutter App | 插件 | **module（add-to-app）** |
|---|---|---|---|
| 宿主 | Flutter | 都不是（被依赖的库） | **原生 App** |
| 依赖方向 | Flutter 用原生能力 | App 依赖插件 | **原生 App 依赖 module** |
| 产物 | 一个完整 App | 可复用能力包 | 一段可嵌入的 Flutter 内容 |

**为什么企业需要它**：没有公司会为了用 Flutter 把跑了五年的几十万行原生 App 推倒重写。现实路径永远是"新模块用 Flutter 写，老代码不动"。

**Q2. iOS 侧怎么接？`install_all_flutter_pods` 到底做了什么？**

Podfile 里三件事：指明 module 路径 → `load podhelper.rb` → target 里 `install_all_flutter_pods`。

这一行替你做的事：把 **`Flutter.framework`（引擎）**、**`App.framework`（Dart 产物）**、以及 module 依赖的**所有插件**都变成 Pod 依赖塞进宿主 target，并为 Debug/Profile/Release 各配好产物路径和构建阶段脚本（那个负责 rsync 产物进 `.app` 的 "Embed Flutter Build" 脚本就是它加的）。

之后**必须用 `.xcworkspace` 打开**——CocoaPods 通例，不是 Flutter 特有。

**Q3.（高频追问）原生同事不想装 Flutter SDK，怎么办？**

改用**产物集成**：由 Flutter 侧/CI 跑 `flutter build ios-framework` 产出 `Flutter.xcframework` + `App.xcframework` + 插件 xcframework，发成私有 pod（Android 侧对应 `flutter build aar` 发 maven）。原生同学像用普通三方库一样依赖它，**不需要装 Flutter SDK**。

代价是 Dart 每次改动都要**重新发一版产物**、原生升版本号——所以选型取决于"Flutter 改得频不频繁""团队构成是什么样"。能把这个取舍讲清楚，基本就答满了。

**Q4. 接入 Flutter 后包体积涨多少？构建时间呢？**

包体积：主要是引擎（`Flutter.framework` / `libflutter.so`）+ ICU 数据 + 你的 Dart AOT 产物，Release 下**通常是 10MB 上下的量级**（随架构、资源和插件数量变化，要以实测为准）。减包手段：控制 ABI、`--split-debug-info`、`--obfuscate`、资源按需下载、少引不必要的插件。

构建时间：源码集成下每次原生构建都要走一遍 Dart 编译（Release 的 AOT 尤其慢），这也是大团队转向产物集成的动因之一。

**Q5. SwiftUI 宿主怎么装 `FlutterViewController`？**

`FlutterViewController` 是 UIKit 的，SwiftUI 里必须用 **`UIViewControllerRepresentable`** 包一层，再用 `.fullScreenCover` / `NavigationLink` 等呈现。

同理，纯 SwiftUI 工程没有 `AppDelegate`，要用 **`@UIApplicationDelegateAdaptor`** 桥到 UIKit 生命周期——官方文档里那段写在 `AppDelegate.didFinishLaunching` 里的引擎预热代码（L9），在 SwiftUI 工程里就落在这儿。

**Q6. 冷启动打开 Flutter 页时的白屏是怎么来的？怎么优化？**

不传 `engine:` 的 `FlutterViewController` 会**当场新建并启动引擎**：起 Dart VM → 加载 `App.framework` → 跑 `main()` → 建 widget 树 → 首帧上屏。这段时间屏幕上没有内容，就是白屏。

优化手段，按性价比排：
1. **引擎预热**（L9 的主角）：App 启动时就 `run()` 好一台常驻引擎，打开页面时复用 → 秒开；
2. **占位/过渡**：原生侧先显示一张与 Flutter 首屏一致的占位图或骨架屏，避免"白"；
3. **首屏轻量化**：Dart 侧首帧别做重活（网络、大列表），把初始化推迟到首帧之后；
4. 折中方案：**进入某个业务域时才预热**，离开时释放，兼顾内存。

**Q7.（本课实测踩到）为什么冷启动路径必须再挂一次 MethodChannel？**

因为 **channel 是绑在引擎上的，不是全局的**。冷启动每次都新建引擎，它和预热引擎是两个世界——在 A 引擎上挂的 handler，B 引擎里的 Dart 调不到（表现为调用石沉大海或 `MissingPluginException`）。

现象很唬人：Flutter 页里的"关闭"按钮点了没反应，**用户被困在页面里出不去**。所以工程上的正确做法是把"挂通道"抽成一个函数（本课的 `attachHostChannel(to:)`），**冷启动路径和预热路径都调它**，从结构上杜绝漏挂。

**Q8. 混合栈里两套路由怎么协调？**

原生有自己的导航栈（`UINavigationController`/`NavigationStack`），Flutter 有自己的 `Navigator`，**两者互不知情**。典型症状：Flutter 页里点自己画的返回按钮，pop 的是 Flutter 的栈，原生这一层纹丝不动（页面还盖着）；或者手势返回归谁管说不清楚。

三种应对：
1. **约定边界**（最简单，本课做法）：Flutter 侧不画返回，**谁 present 的谁负责 dismiss**，需要退出就通过通道通知宿主；
2. **原生驱动路由**：宿主通过通道让 Flutter 侧 `Navigator` 跳转（L9 做的那件事）；
3. **上框架**：`flutter_boost` 这类混合栈框架把两套路由统一成一套 API——收益是省心，代价是引入一个较重的、与引擎耦合的第三方依赖，升级 Flutter 时要一起等它适配。

**Q9. add-to-app 怎么调试和热重载？**

`flutter run` 不适用（启动入口在原生工程）。正确姿势：**Xcode/Android Studio 跑起宿主 App → 在 module 目录执行 `flutter attach`**，工具连上设备里的 Dart VM，之后热重载、DevTools、日志全都照常。真机上若要求本地网络权限，补 `NSBonjourServices` / `NSLocalNetworkUsageDescription` 两个 Info.plist 键。
