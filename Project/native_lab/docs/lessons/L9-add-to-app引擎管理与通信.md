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

**6. ★ 混合栈的三种工程方案（选型题，面试常考）。**

| 方案 | 做法 | 优点 | 代价 |
|---|---|---|---|
| **单引擎 + 单入口**（本课） | 一台常驻引擎，原生 present 一个 Flutter 页，Flutter 内部自己路由 | 简单、内存可控、无第三方依赖 | 原生页和 Flutter 页**不能自由交错入栈**；边界要手动协调 |
| **多引擎**（`FlutterEngineGroup`） | 每个 Flutter 界面一台引擎 | 页面之间彻底隔离，可任意交错 | 内存随页面数增长；**各引擎状态不共享**（通道、单例、缓存都要各算一份） |
| **混合栈框架**（如 flutter_boost） | 框架接管两侧路由，页面可自由交错 | 开发体验最接近"一套路由" | 依赖重、与引擎实现耦合，**Flutter 升级要等它适配**；出问题排查成本高 |

判断口诀：**Flutter 页面是"少数几个独立入口" → 单引擎；"要和原生页大量交错" → 才考虑多引擎或框架。** 不要一上来就上 boost。

**7. 引擎的释放：`destroyContext()` 与"页面关了 Dart 还在跑"。**

页面关闭只是移除了显示窗口，引擎还在：**不再渲染（没有可见视图），但 Dart 侧的定时器、流订阅、网络回调仍会继续执行**。这既是"状态常驻"的来源，也意味着**忘了取消的轮询会一直烧电**——所以 add-to-app 里的 Dart 代码要格外注意在页面 `dispose` 时清理副作用。

真要彻底放掉一台引擎：iOS 调 `engine.destroyContext()`（Android 是 `engine.destroy()` 并从 `FlutterEngineCache` 移除），之后这台引擎**不可再用**，需要重新创建并 `run()`。折中策略是"**进入业务域预热、离开业务域销毁**"。

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
| `engine.destroyContext()` | 彻底释放引擎（Android 是 `engine.destroy()`） | 之后引擎**不可再用**，要重新创建并 `run()` |

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

## 八、面试高频题（附答案）

> 面试语境：**这一课的题几乎全是"取舍题"**，没有标准答案，考的是你有没有在真项目里权衡过。回答模板：先给结论，再给代价，最后给"什么情况下我会反过来选"。

**Q1. 什么是引擎预热？收益和代价分别是什么？什么情况下不该预热？**

预热 = App 启动时就创建并 `run()` 一台常驻 `FlutterEngine`（顺带注册插件、挂通道），打开页面时用 `FlutterViewController(engine:)` **复用**它，把"起 Dart VM + 跑 main + 建 widget 树"的耗时从**用户点击那一刻**挪到了**App 启动阶段**——效果就是秒开、没有白屏。

代价有两条，都要说：① **内存常驻**（一台引擎几十 MB 量级）；② **拖慢 App 启动**（把耗时挪走了，但没消失，落在了启动路径上）。

不该预热的情况：**极少进的边角功能**（一年用一次的活动页）——白占内存还拖慢启动。折中：进入某个业务域时才预热，离开时 `destroyContext()` 释放。

**Q2. `FlutterEngine` 只 `new` 不 `run()` 会怎样？为什么 `run()` 要加守卫？**

只 `new` 不 `run()`：引擎对象存在，但**没有 isolate、不执行任何 Dart 代码**，你在它的 messenger 上挂通道也收不到任何东西。

`run()` 要加标志位守卫，是因为**对同一台引擎重复 `run()` 是错误用法**（Dart 入口已经在跑了）。真实工程里预热可能被多处触发（`didFinishLaunching`、场景恢复、业务域入口），所以守卫必须有。

**Q3. 为什么关掉 Flutter 页之后，模块还记得之前的 token？这是好事还是坏事？**

因为**关的只是显示窗口（`FlutterViewController`），引擎和 Dart 的 widget 树、内存根本没销毁**。引擎常驻 = **状态常驻**。

双刃剑：好处是秒开 + 状态延续（像原生页一样"还在那儿"）；坏处是**用户以为关掉了，其实没重置**——上一个用户的数据可能还在（在需要登录态隔离的 App 里这甚至是**安全问题**）。

想重置就得**显式做**：在通道里加一个 `resetModule` 方法，关闭时调一次，Dart 侧清状态 + `pushNamedAndRemoveUntil('/')` 回到首页。

**Q4.（本课最容易踩的坑）为什么热引擎上 `setInitialRoute` 无效？正确做法是什么？**

`initialRoute` 是 Dart 侧 `MaterialApp` **构建 widget 树那一刻**读的值。预热引擎在 App 启动时就 `run()` 了，widget 树早建好——这时候再 `navigationChannel.invokeMethod("setInitialRoute", ...)`，改的是一个**没人再读**的值。现象是"点开 /detail，打开的还是首页"。

正确做法：**自己开一个通道方法驱动 `Navigator`**。Dart 侧因为此刻没有任何 `BuildContext`，需要一个全局 `GlobalKey<NavigatorState>`：

```dart
final moduleNavigatorKey = GlobalKey<NavigatorState>();
MaterialApp(navigatorKey: moduleNavigatorKey, ...);
// 收到 setRoute：
moduleNavigatorKey.currentState?.pushNamedAndRemoveUntil(route, (_) => false);
```

一句话记法：**`setInitialRoute` 只对"还没 run 起来的引擎"有效；跑起来了就得驱动 Navigator。**（用 `pushNamedAndRemoveUntil` 而不是 `pushNamed`，是为了防止反复进入把栈越堆越深。）

**Q5. 为什么模块不能自己 `Navigator.pop()` 关掉页面？**

因为那个页面是**原生 present 的**，它在 Flutter 的路由栈里是**根页**——pop 掉只剩一片黑，而原生的 `fullScreenCover` 还盖在那儿，用户被困住。

原则：**谁 present 的，谁负责 dismiss**。模块要退出就通过通道发一个 `closePage` 请宿主关自己。这条在任何"寄居"场景里都成立（对照 L4：那时是 Flutter 去 present 原生页，dismiss 也归 Flutter 触发的那一侧管）。

**Q6. 什么时候需要多个引擎？为什么用 `FlutterEngineGroup` 而不是 new 一堆 `FlutterEngine`？**

需要**同时并存多个互不相干的 Flutter 界面**时（比如两个 tab 各是一个 Flutter 模块，或原生页和 Flutter 页大量交错入栈）。

手动 new 多个引擎，每台都要吃一份完整内存；`FlutterEngineGroup` **spawn** 出来的引擎**共享代码段、字体和部分只读资源**，增量内存显著更小。但要清楚：每个 spawn 的引擎仍有**自己的 isolate、自己的 widget 树、自己的通道**——**通道绑引擎**这条铁律不变，所以每台引擎都要各自挂一次通道、各自注册插件；**状态也不共享**（Dart 侧的单例、缓存都要各算一份）。

**Q7. 混合栈方案怎么选？要不要上 flutter_boost？**

先讲三种方案的取舍（见正文第 6 点表），再给判断口诀：**Flutter 页面是"少数几个独立入口" → 单引擎足够；要和原生页大量交错 → 才考虑多引擎或混合栈框架。**

对 flutter_boost 的评价要中立：它确实把两套路由统一成了一套 API，开发体验好；代价是**依赖重、与引擎实现耦合，Flutter 升级要等它适配**，一旦出问题排查成本高。所以是"业务形态确实需要交错时才付这个代价"，不是默认选项。

**Q8. 原生调 Flutter（`channel.invokeMethod` 带 result 回调）要注意什么？**

三点：① 回调里的 `value` **可能是 `FlutterError`**（Dart 侧抛了异常），必须判断，不能直接强转；② 也可能是 `FlutterMethodNotImplemented`（Dart 侧没实现这个方法名）；③ **Dart 侧还没起来/已经销毁时调用会没有响应**——原生侧要有超时兜底，别让业务逻辑挂在一个永远不回的回调上（对照 L1：channel 两个方向都没有超时机制）。

**Q9.（收尾大题）让你给一个几十万行的原生 App 设计 Flutter 混合方案，你会怎么做？**

按这个顺序答，基本覆盖整门课：

1. **接入方式**：先定源码集成还是产物集成——原生团队大、不想装 Flutter SDK 就走 `build ios-framework` / `build aar` 的产物集成，卡版本发布；
2. **引擎策略**：默认**单引擎预热**（高频入口值得，启动耗时可接受），边角模块走冷启动；确需交错才上 `FlutterEngineGroup`；
3. **通信层**：宿主能力（登录态、埋点、支付、分享、路由）收口成**一个宿主通道**，用 **Pigeon 定契约**保证双端类型安全，**通道挂载抽成一个函数**让所有引擎路径复用（防漏挂）；
4. **路由**：约定"谁 present 谁 dismiss"，原生驱动 Flutter 换页走通道 + 全局 `navigatorKey`；deeplink/推送落到模块某页也走这条；
5. **状态管理**：明确 `resetModule` 语义——引擎常驻意味着状态不会自动重置，登录态切换、用户退出必须显式清；
6. **工程化**：module 独立仓库/独立 CI，产物版本化；Dart 侧单测覆盖通道协议，宿主侧靠真机/模拟器实跑冒烟；`flutter attach` 做调试；
7. **可观测性**：`PlatformException` / `MissingPluginException` 上报监控（后者代表**契约漂移**，是 bug 不是业务分支）；包体积和启动耗时进性能看板。

最后补一句判断力：**混合开发没有银弹，收益来自"新模块用 Flutter 写得快"，成本落在"边界上的事得自己接住"**——所以边界要少、要清晰、要收口成一层。
