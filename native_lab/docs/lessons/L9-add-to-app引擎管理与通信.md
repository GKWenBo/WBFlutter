# L9 add-to-app：引擎管理与通信

> 企业场景：L8 把 Flutter 接进原生 App 了，但那只是"能跑"。真上线要面对三个问题：**① 点开就白屏**（每次新建引擎）；**② 模块要用原生的登录态、原生要读模块的状态**（双向通信）；**③ 原生要能决定打开模块的哪一页**（混合路由）。本课把这三件事解决掉——这才是混合 App 的工程化形态，也是整门课的收官。

## 一、本课要掌握什么

**1. ★ 引擎预热：用启动时的一次开销，换用户点开时的秒开。**

L8 的做法是"打开页面时才建引擎"，代价是白屏。预热就是把这个开销**挪到 App 启动时**：

```swift
final class FlutterHostEngine {
    static let shared = FlutterHostEngine()
    let engine = FlutterEngine(name: "wb.host.engine")   // 常驻引擎

    func warmUp() {
        engine.run()                                      // ① 跑起来（耗时大头，提前做掉）
        GeneratedPluginRegistrant.register(with: engine)  // ② 给这个引擎注册插件
        channel = attachHostChannel(to: engine.binaryMessenger) { ... }  // ③ 挂通道
    }
}
```

打开页面时**传入**这个引擎，就不再新建：

```swift
FlutterViewController(engine: host.engine, nibName: nil, bundle: nil)  // 复用 → 秒开
```

**SwiftUI 在哪调 `warmUp()`？** SwiftUI 没有 AppDelegate，用 `@UIApplicationDelegateAdaptor` 桥到 UIKit 生命周期——Flutter 官方文档里写在 AppDelegate 的那段预热代码，在 SwiftUI 工程里就落在这儿：

```swift
@main
struct WBiOSProjectApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    ...
}
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_:didFinishLaunchingWithOptions:) -> Bool {
        FlutterHostEngine.shared.warmUp()
        return true
    }
}
```

**★ 取舍**：预热不是免费的。引擎常驻 = **内存常驻**（一个引擎几十 MB 量级）。所以：
- 模块是**高频入口**（比如首页的一个 tab）→ 值得预热；
- 模块是**极少进的边角功能**（一年用一次的活动页）→ 冷启动就行，别白占内存；
- 折中：进入某个业务域时才预热，离开时 `destroyContext()` 释放。

**2. ★ 引擎决定一切：通道、状态、生命周期都跟着引擎走。**

L8 已经踩过"通道绑在引擎上"的坑。预热引擎还带来一个**副作用（也是特性）**：引擎常驻 → **Dart 侧的状态也常驻**。

本课实测能看到：打开 Flutter 页 → 取 token → 关闭页面 → 再点"原生反问模块"，模块**仍然记得那个 token**。因为页面关的只是"显示窗口"（FlutterViewController），Dart 那边的 widget 树和内存**根本没销毁**。

这是双刃剑：
- 好处：秒开、状态延续（像原生页一样"还在那儿"）。
- 坏处：用户以为"关掉了"，其实**没重置**。需要清空状态就得自己在通道里加一个 `reset` 方法显式清。

**3. ★ 双向通信：这次原生是"调用方"也是"被调方"。**

L1–L7 里方向是固定的（Flutter 调原生 / 原生推 Flutter）。add-to-app 里两个方向都很日常：

| 方向 | 本课例子 | 企业真实场景 |
|---|---|---|
| Flutter → 原生 | `getUserToken`：模块向宿主要登录态 | 登录态、埋点、支付、分享都在原生手里 |
| Flutter → 原生 | `closePage`：模块请宿主关掉自己 | 模块流程走完，通知宿主退出 |
| 原生 → Flutter | `getPageState`：宿主问模块当前状态 | 宿主要做埋点/拦截返回/保存草稿 |
| 原生 → Flutter | `setRoute`：宿主让模块换页 | 推送点击、deeplink 落到模块某页 |

**★ 为什么模块不能自己 `Navigator.pop` 关页面？** 因为那个页面是**原生 present** 的，它在 Flutter 路由栈里是**根页**——pop 掉只会剩一片黑，原生的 `fullScreenCover` 还盖在那儿。**谁 present 的，谁负责 dismiss**。

**4. ★★ 混合路由最大的坑：热引擎上 `setInitialRoute` 是无效的。**

这是本课实测踩到、并且**很多人第一次都会踩**的坑：

```swift
// ❌ 对【已经 run() 的引擎】无效
engine.navigationChannel.invokeMethod("setInitialRoute", arguments: "/detail")
```

原因很直白：`initialRoute` 是 Dart 侧 `MaterialApp` **构建 widget 树那一刻**读的值。预热引擎在 App 启动时就 `run()` 了，widget 树早建好了——这时再设，只是改了个**没人再读**的值。现象是：点"打开 /detail"，结果打开的还是首页。

**热引擎换页的正确做法**：自己开一个通道方法，让 Dart 侧真正去 `Navigator` 上跳：

```dart
// Dart 侧：需要一个全局 navigatorKey，因为此刻没有任何 BuildContext
final moduleNavigatorKey = GlobalKey<NavigatorState>();
MaterialApp(navigatorKey: moduleNavigatorKey, ...)

case 'setRoute':
  moduleNavigatorKey.currentState
      ?.pushNamedAndRemoveUntil(route, (_) => false);  // 清栈再进，防止越堆越深
```

一句话记法：**`setInitialRoute` 只对"还没跑起来的引擎"有效；跑起来了就得驱动 Navigator。**

**5. 多引擎与 FlutterEngineGroup。**

如果宿主要**同时**显示多个互不相干的 Flutter 页面（比如 tab 里两个 Flutter 模块），单引擎就不够了。直接 new 多个 `FlutterEngine` 会各自吃一份内存；官方给了 `FlutterEngineGroup`：

- 从同一个 group spawn 出来的引擎**共享**代码段、字体、部分只读资源，增量内存远小于独立引擎；
- 每个 spawn 的引擎有**自己的** isolate、自己的 widget 树、**自己的通道**（还是那句：通道绑引擎）。

本课不实现多引擎（YAGNI），但你要知道：**需要多个并存的 Flutter 界面时，用 `FlutterEngineGroup`，不要手动 new 一堆引擎。**

## 二、控件 / API 速查表

| API | 说明 | 坑 |
|---|---|---|
| `FlutterEngine(name:)` | 创建引擎 | 光创建不 `run()` 不会执行 Dart |
| `engine.run()` | 启动引擎跑 `main()` | **别重复调**，要用标志位守卫 |
| `GeneratedPluginRegistrant.register(with: engine)` | 给这个引擎注册插件 | 每个引擎都要注册一次 |
| `FlutterViewController(engine:nibName:bundle:)` | 复用引擎的 VC | 这是"秒开"的来源 |
| `@UIApplicationDelegateAdaptor` | SwiftUI → UIKit 生命周期桥 | 预热代码的落点 |
| `engine.binaryMessenger` | 引擎的信使 | 通道挂这上面，跟引擎同寿命 |
| `channel.invokeMethod(_:arguments:result:)` | **原生调 Flutter** | 回调里 `value` 可能是 `FlutterError` |
| `navigationChannel` + `setInitialRoute` | 设初始路由 | **只对没 run 的引擎有效** |
| `GlobalKey<NavigatorState>` | Dart 侧全局导航句柄 | 热引擎换页靠它 |
| `FlutterEngineGroup` | 多引擎共享资源 | 需要多个并存 Flutter 界面时用 |

## 三、代码地图

**原生宿主 `WBiOSProject/`**
- `FlutterHost.swift`
  - `attachHostChannel(to:onClose:)` — 把通道挂到**任意引擎**的 messenger 上（冷/热两条路共用）。
  - `FlutterHostEngine` — 常驻引擎单例：`warmUp()`（run + 注册插件 + 挂通道）、`queryModuleState()`（原生→Flutter）、`setRoute()`（通道驱动导航）。
  - `WarmFlutterPage` — 复用常驻引擎的 `UIViewControllerRepresentable`。
- `WBiOSProjectApp.swift` — `@UIApplicationDelegateAdaptor` + `AppDelegate` 里 `warmUp()`。
- `ContentView.swift` — 四个入口（L8 冷启动 / L9 秒开 / L9 路由 / L9 反问）。

**Flutter 模块 `flutter_module/`**
- `lib/host_bridge.dart` — `moduleNavigatorKey`；接收 `getPageState`、`setRoute`；发出 `getUserToken`、`closePage`。
- `lib/main.dart` — `MaterialApp(navigatorKey:)` + 路由表 + 两个页面。

## 四、测试怎么写

- **模块侧 Dart 单测**（`test/host_bridge_test.dart`）：
  - Flutter→原生：断言 `getUserToken` / `closePage` 发出的 method call 顺序与参数。
  - 原生→Flutter：用真实 codec 编一条 `getPageState` 消息喂给接收端，断言应答内容。
- **宿主侧靠模拟器实跑**（跨进程 + 构建系统，测不了）：本课四条路径全部实点验证过：
  1. 冷启动开页（含冷引擎自己的通道：要 token ✅、关闭 ✅）
  2. 预热引擎秒开 ✅
  3. `/detail` 路由协调 ✅
  4. 原生反问模块状态 ✅（且关页面后引擎仍记得 token，印证"引擎常驻=状态常驻"）

## 五、iOS 专属说明（Android 侧概念差异）

| | iOS | Android |
|---|---|---|
| 预热引擎 | 自己持有 `FlutterEngine` 单例 | `FlutterEngineCache.getInstance().put(id, engine)` |
| 复用引擎 | `FlutterViewController(engine:)` | `FlutterActivity.withCachedEngine(id).build(ctx)` |
| 预热时机 | `AppDelegate.didFinishLaunching` | `Application.onCreate` |
| 多引擎 | `FlutterEngineGroup` | `FlutterEngineGroup`（同名） |
| 路由 | 同样：热引擎需通道驱动 Navigator | 同样 |

## 六、自测清单

1. 引擎预热解决了什么问题？它的代价是什么？什么情况下**不该**预热？
2. `FlutterEngine` 只 `new` 不 `run()` 会怎样？为什么 `run()` 要加守卫？
3. 为什么"关掉 Flutter 页"之后，模块还记得之前取到的 token？这是好事还是坏事？想重置该怎么做？
4. 为什么模块不能自己 `Navigator.pop()` 关闭被原生 present 的页面？
5. **热引擎上 `setInitialRoute` 为什么无效？** 正确的换页做法是什么？为什么 Dart 侧需要一个全局 `navigatorKey`？
6. 什么时候需要多个引擎？为什么要用 `FlutterEngineGroup` 而不是手动 new 几个 `FlutterEngine`？
7. 回顾整门课：L1 的 MethodChannel 和 L9 的宿主通道，在**方向**和**谁是宿主**上分别是什么关系？

> 自测答案见 [自测答案/L9-自测答案.md](自测答案/L9-自测答案.md)。

## 七、课后练习

给宿主通道加一个 `resetModule` 方法，解决第 3 题暴露的问题：

1. Dart 侧 `host_bridge.dart` 加 `case 'resetModule'`：清空页面状态（token 置空）并 `pushNamedAndRemoveUntil('/')` 回到首页；
2. Swift 侧 `FlutterHostEngine` 加 `func resetModule()` 调它；
3. `WarmFlutterPage` 在 Flutter 页**关闭时**（`onClose` 里）调一次，让下次打开是干净的；
4. 补一条 Dart 测试：喂一条 `resetModule` 消息，断言状态被清。

练的是混合 App 里最现实的一个决策：**引擎常驻带来的"状态不会自动重置"，必须由你显式管理**——这也是整门课最后一个知识点：**混合开发没有银弹，边界上的事得自己接住。**
