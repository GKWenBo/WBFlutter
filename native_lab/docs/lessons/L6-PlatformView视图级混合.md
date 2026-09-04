# L6 PlatformView 视图级混合

> 企业场景：前五课的桥都在**传数据**（Flutter 调原生取值、原生推事件回来）。但有些东西传数据传不出来——一块**真地图**、一个**网页容器**、一个**相机预览**、一个**广告 SDK 的横幅视图**：它们是**原生 UI 控件**，Flutter 自己画不出来。PlatformView 就是把这种**原生视图当成一个 Flutter widget 嵌进布局里**，和 Flutter 控件同屏共存。本课 **iOS 嵌真 `MKMapView`、Android 嵌原生 `WebView`**——两端嵌的东西不同，但**嵌入机制完全一样**，这本身就是本课要点。

对照 **L4 页面级混合**：L4 是"整屏交给原生 VC/Activity，拿到结果就退出"；L6 是"原生视图作为**一个 widget** 长在 Flutter 页面里，上面有 Flutter 说明卡、下面有 Flutter 按钮，三者同屏"。

## 一、本课要掌握什么

**1. PlatformView 是"把原生视图嵌成 widget"，不是新的通信机制。**

底层仍是 channel（创建参数走 `StandardMessageCodec`、控制走 `MethodChannel`），前五课的心智全都还在。新东西只有**嵌入这套管道**：Dart 用 `UiKitView`/`AndroidView` 按 `viewType` 占位，原生用 **Factory** 按 `viewType` 产出真实原生视图。

**2. ★ viewType + Factory：机制两端一致，产物各端自定（本课最核心的认知）。**

| | Dart 侧 | iOS | Android |
|---|---|---|---|
| 嵌入 | `UiKitView(viewType:)` / `AndroidView(viewType:)` | — | — |
| 注册 | — | `registrar.register(factory, withId: viewType)` | `registry.registerViewFactory(viewType, factory)` |
| 产物 | — | `FlutterPlatformViewFactory` → `MKMapView` | `PlatformViewFactory` → `WebView` |

**同一个 `viewType` 字符串**（`com.wenbo.native_lab/native_view`）把三端串起来。Dart 只说"我要嵌一个这种类型的视图"，至于它落地成地图还是网页，是各端 Factory 自己的事——这正还原了真实开发里"iOS 用 MapKit、Android 用 WebView/高德"的常态。

**3. ★ 每实例一条方法通道（和前五课最大的区别）。**

L1–L5 都是**应用级单例 channel**：一个 App 一条 `com.wenbo.native_lab/device_info`。PlatformView 不同——**每个视图实例一条 channel**，名字带 `viewId`（`com.wenbo.native_lab/native_view_<viewId>`）。因为一个页面可能同时嵌**多个同类原生视图**（两张地图、三个网页），必须能分别寻址。`viewId` 从 `onPlatformViewCreated: (int id)` 拿到，Dart 侧据此为每个实例建一个控制器。

**4. 创建参数（creationParams）：创建时一次性把初始状态传给原生。**

`UiKitView(creationParams: {...}, creationParamsCodec: StandardMessageCodec())`。原生 Factory 的 `createArgsCodec()` 必须**和 Dart 侧 codec 对齐**（都用 Standard），否则参数解不出来。本课 iOS 传初始地图区域 `{lat,lng,span}`、Android 传初始 URL `{url}`。这是"创建时"的单向传参；创建后要控制视图，走第 3 点的方法通道。

**5. 性能代价 & 和 L4 怎么选。**

原生视图要和 Flutter 的渲染树**合成到一起**（纹理拷贝 / 额外图层 / 有时触发线程同步），比纯 Flutter widget 贵。所以：**能用 Flutter 画的就别嵌**；只有当你需要一个 Flutter 造不出的**真实原生 SDK 视图**（地图/网页/相机/广告）时才用 PlatformView。选型对照见第五节。

**6. ★ 合成模式：贵在哪里（Android 三种模式 + iOS 的交错合成）。**

Flutter 的画面本来是**一整块自绘 surface**。要把一个原生视图"夹"进这块画面里（下面有 Flutter 背景、上面有 Flutter 按钮），引擎只有两条路：**要么把原生视图渲染成纹理贴进来，要么把 Flutter 的画面拆成多层、让原生视图真的插在中间**。两条路各有代价，这就是 PlatformView 的全部开销来源。

Android 侧历史上出现过三种模式：

| 模式 | 做法 | 代价 / 问题 |
|---|---|---|
| **Virtual Display（VD，最早）** | 原生 view 渲染到一块虚拟显示的纹理，再当图片贴进 Flutter | 触摸事件要**转发**过去，文本输入、无障碍、部分动画会出问题 |
| **Hybrid Composition（HC）** | 原生 view **真实加进 Android 视图层级**，Flutter 画面拆成上下两层与它交错 | 输入/无障碍正常；早期版本开销明显（需要平台线程参与合成） |
| **Texture Layer Hybrid Composition（TLHC，Flutter 3.0 起的默认）** | 折中：view 留在层级里处理输入，内容渲染进纹理由 Flutter 合成 | 大多数场景下的最佳平衡；部分特殊 view（有自定义 surface 的）会自动回退到 HC |

日常写 `AndroidView` 由框架**自动选**模式；需要强制 HC 时才用 `PlatformViewLink` + `initExpensiveAndroidView`。iOS 侧只有一条路：原生 `UIView` 真实加入 UIKit 层级，引擎把 Flutter 图层拆开与之交错——**这就是为什么 iOS 侧嵌得越多、图层拆得越碎、越慢**（历史版本还会触发 platform 与 raster 线程合并，新版本引擎已大幅优化）。

**结论（面试直接说这句）：PlatformView 的代价不是"多画一个 view"，而是"把 Flutter 原本一整块的合成拆开了"。所以要少用、别嵌一堆、别放进长列表反复创建销毁。**

**7. ★ 手势冲突：谁吃这一下触摸？**

原生视图嵌在 Flutter 里，触摸事件要在两套手势系统之间分配。默认行为是：**Flutter 的手势竞技场（gesture arena）先裁决**，只有 Flutter 侧没有 widget 认领这个手势时，事件才交给原生视图。

后果很典型：地图外面套了个 `ListView`/`PageView`，你在地图上拖动，**父级的滚动先赢了**，地图纹丝不动。

解法是给 `UiKitView`/`AndroidView` 传 `gestureRecognizers`，把手势"抢"给原生视图：

```dart
UiKitView(
  viewType: kNativeViewType,
  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
  },
)
```

`EagerGestureRecognizer` 的意思是"**立刻赢下竞技场**"——所有落在这个视图上的手势直接归原生。也可以只声明 `PanGestureRecognizer` 等特定类型做精细划分。

相关的还有**键盘输入**：Android 的 VD 模式下原生输入框的焦点/输入法会出问题，这也是当年推 Hybrid Composition 的直接动因；今天用 TLHC/HC 基本正常，但"嵌一个带输入框的原生视图"仍然是要专门验证的场景。

## 二、控件 / API 速查表

### Dart 侧（本课新东西）

| API | iOS 类比 | 用法 & 关键点 | 坑 |
|---|---|---|---|
| `UiKitView(viewType:...)` | 把一个 `UIView` 塞进布局 | 按 `viewType` 嵌 iOS 原生视图 | 需要有界尺寸（本课用 `Expanded` 给高度） |
| `AndroidView(viewType:...)` | 把一个 `View` 塞进布局 | 按 `viewType` 嵌 Android 原生视图 | 无输入的展示型视图用它够了；要键盘输入才需 hybrid composition |
| `creationParams` + `creationParamsCodec` | 初始化参数 | 创建时一次性传原生，codec 两端要对齐 | codec 不一致 → 原生解不出参数 |
| `onPlatformViewCreated: (int id)` | 视图创建完成回调 | 拿 `viewId` 建每实例控制器 | 视图未创建前控制器为 null，按钮要判空 |
| `MethodChannel('..._$viewId')` | 每实例一条通道 | 控制单个视图（reload/setMapType…） | 名字必须带 viewId，别退回应用级单例 |

### iOS 侧

| API | 说明 | 坑 |
|---|---|---|
| `FlutterPlatformViewFactory` | 按 viewType 产出视图实例 | `createArgsCodec()` 要返回 `FlutterStandardMessageCodec.sharedInstance()` |
| `FlutterPlatformView`（`func view()`） | 把要嵌的 `UIView` 交出去 | 本课交出 `MKMapView` |
| `registrar.register(_:withId:)` | 绑定 viewType 和工厂 | 用 `applicationRegistrar`（本工程应用级桥的注册口） |

### Android 侧

| API | 说明 | 坑 |
|---|---|---|
| `PlatformViewFactory(StandardMessageCodec.INSTANCE)` | 按 viewType 产出视图 | codec 要和 Dart 对齐 |
| `PlatformView`（`getView()`/`dispose()`） | 交出 `View` + 释放 | `dispose()` 里 `webView.destroy()` 防泄漏 |
| `registry.registerViewFactory(viewType, factory)` | 注册工厂 | `flutterEngine.platformViewsController.registry` |
| `<uses-permission INTERNET/>` | WebView 加载网页 | 忘了加 → 网页白屏 |

## 三、代码地图

**Dart 侧（手写）**
- `lib/lessons/l6/native_platform_view.dart` — `kNativeViewType` 常量；`NativeViewController`（每实例方法通道封装：`setMapType`/`resetRegion`/`reload`/`loadUrl`）；`NativePlatformView`（按 `defaultTargetPlatform` 返回 `UiKitView`/`AndroidView`，`onPlatformViewCreated` 里造控制器回调）。
- `lib/lessons/l6/l6_platform_view_page.dart` — 页面：说明卡 + `Expanded(NativePlatformView)` + `_ControlBar`（按平台显示地图/网页控制按钮）。
- `lib/lessons/lesson_registry.dart` — L6 `inProgress` + `pageBuilder`。

**iOS 侧（手写实现）**
- `ios/Runner/MapPlatformView.swift` — `MapViewFactory`（工厂）+ `MapPlatformView`（持 `MKMapView` + 每实例方法通道，读创建参数设初始区域，`setMapType`/`resetRegion`）。
- `ios/Runner/AppDelegate.swift` — 第六处：`registrar.register(MapViewFactory(...), withId:)`。
- `ios/Runner.xcodeproj/project.pbxproj` — 手动加新 `.swift`（本工程无 synchronized groups，同 L5）。

**Android 侧（手写实现）**
- `android/.../WebPlatformView.kt` — `WebViewFactory`（工厂）+ `WebPlatformView`（持 `WebView` + 每实例方法通道，读创建参数设初始 URL，`reload`/`loadUrl`）。
- `android/.../MainActivity.kt` — `registry.registerViewFactory(...)`。
- `android/.../AndroidManifest.xml` — 加 `INTERNET` 权限。

## 四、测试怎么写（本课的新姿势）

PlatformView 的**原生视图无法在 widget test 里真渲染**（没有原生宿主），所以只测 **Dart 侧能测的**：

```dart
// 1) 控制器把动作正确编码成 method call（mock 该实例的通道，断言 method+args）
const channel = MethodChannel('com.wenbo.native_lab/native_view_7');
messenger.setMockMethodCallHandler(channel, (call) async { calls.add(call); return null; });
await NativeViewController(7).setMapType('satellite');
expect(calls.single.method, 'setMapType');

// 2) 按平台产出正确的 widget（debugDefaultTargetPlatformOverride 切平台）
//    先 mock 掉 SystemChannels.platform_views，让 UiKitView/AndroidView 在测试环境不抛错
messenger.setMockMethodCallHandler(SystemChannels.platform_views,
    (call) async => call.method == 'create' ? 0 : null);
```

- `NativeViewController` 编码测试（正向控制）。
- `NativePlatformView` 按平台产出 `UiKitView`/`AndroidView`（需 mock `flutter/platform_views` 系统通道，否则真去创建原生视图会抛错）。
- L6 页面 build 冒烟。
- `lesson_list_test` 锁定样本从 L6 顺移到 L7。

## 五、双端对照（Swift vs Kotlin）

| 维度 | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| 嵌入 widget | `UiKitView` | `AndroidView` |
| 原生视图 | 真 `MKMapView` | `WebView` |
| 工厂基类 | `FlutterPlatformViewFactory` | `PlatformViewFactory(StandardMessageCodec.INSTANCE)` |
| 视图协议 | `FlutterPlatformView`（`view()`） | `PlatformView`（`getView()`/`dispose()`） |
| 注册口 | `registrar.register(_:withId:)` | `registry.registerViewFactory(_,_)` |
| 创建参数 codec | `FlutterStandardMessageCodec.sharedInstance()` | `StandardMessageCodec.INSTANCE` |
| 控制动作 | `setMapType`（标准/卫星）/`resetRegion` | `reload`/`loadUrl` |
| 额外权限 | 无 | `INTERNET`（WebView 联网） |
| 合成模式 | Hybrid（iOS 默认） | 虚拟显示（本课）/ Hybrid composition（需键盘输入时） |

**PlatformView vs L4 页面级混合怎么选：**

| | L4 页面级混合 | L6 PlatformView |
|---|---|---|
| 形态 | 整屏原生页，present/finish | 原生视图作为 widget 嵌在 Flutter 布局里 |
| 共存 | 原生页期间 Flutter 不可见 | 原生视图与 Flutter 控件**同屏** |
| 适用 | 一次性任务（扫码、拍照、原生登录流） | 需要**长驻同屏**的原生视图（地图、网页、相机预览） |
| 代价 | 低（就是切页面） | 高（渲染合成开销） |

> 本课 iOS 主讲、模拟器验证；Android 为完整对照实现（本机不强制跑安卓）。

## 六、自测清单

1. `viewType` 在三端各出现在哪里？如果 iOS 的 `withId:` 和 Dart 的 `viewType` 写得不一致会怎样？
2. 为什么 PlatformView 要**每实例一条通道**、而不是像前五课那样一条应用级单例？`viewId` 从哪来？
3. `creationParams` 和"创建后的方法通道"分别解决什么？为什么原生 Factory 的 codec 必须和 Dart 对齐？
4. PlatformView 的**性能代价**来自哪里？据此，什么时候该用它、什么时候宁可用 Flutter 自己画？
5. 同样是"混原生"，L6 和 L4 页面级混合在形态和适用场景上怎么选？
6. 本课为什么不用 widget test 去验证地图/网页真的显示了？那测什么？

> 自测答案见 [自测答案/L6-自测答案.md](自测答案/L6-自测答案.md)。

## 七、课后练习

给 PlatformView 加**反向回调（native → Flutter）**，把"原生视图的状态变化"回报给 Flutter 显示在控制条上：

1. iOS：`MapPlatformView` 让 `MKMapView` 的 delegate 实现 `mapView(_:regionDidChangeAnimated:)`，把当前中心坐标经**同一条实例通道** `invokeMethod`（或另建一条）回给 Dart；
2. Android：`WebPlatformView` 给 `WebViewClient` 覆写 `onPageFinished`，把页面标题回给 Dart；
3. Dart：`NativeViewController` 上加 `setMethodCallHandler` 接收反向调用，转成回调 / `ValueNotifier`，页面订阅显示；
4. 补一条测试：mock 该实例通道**从原生方向**发一次调用，断言 Dart 侧收到并更新。

练的就是"PlatformView 也能双向"——把 L3/L5 学的"原生主动回话"落到**单个视图实例**这条通道上。

## 八、面试高频题（附答案）

> 面试语境：只要你简历上出现过"地图/WebView/相机/广告"，PlatformView 几乎必问，而且会直奔**性能**和**手势冲突**这两个真实痛点。

**Q1. PlatformView 的原理是什么？为什么说它比普通 widget 贵？**

Flutter 的画面本是**一整块自绘 surface**。嵌入原生视图意味着要在这块画面中间插一层"不是 Flutter 画的东西"，引擎只能：把原生视图**渲染成纹理**贴进来，或者把 **Flutter 的图层拆成多层**让原生视图真的插在中间。前者要纹理拷贝和事件转发，后者要多层合成与线程配合。

所以代价不是"多画一个 view"，而是**把原本一次性的合成拆开了**——嵌得越多、层次越复杂，开销越大。

**Q2. Android 上的 Virtual Display / Hybrid Composition / TLHC 是什么？现在默认用哪个？**

见正文第一节第 6 点的表：VD 最早（用纹理，输入/无障碍有问题）→ HC（view 真实入层级，输入正常但早期开销大）→ **TLHC 是 Flutter 3.0 起 `AndroidView` 的默认**（折中：留在层级里处理输入、内容走纹理）。特殊 view 会自动回退到 HC；需要强制 HC 时用 `PlatformViewLink` + `initExpensiveAndroidView`。

iOS 侧没有这几种模式之分，一直是"真实 `UIView` 加入层级 + Flutter 图层交错"。

**Q3. 原生视图上的手势和 Flutter 的手势冲突了怎么办？**

默认 **Flutter 的手势竞技场优先**，只有没人认领时事件才给原生视图。典型症状：地图外套着可滚动父级，拖地图变成了滚页面。

解法：给 `UiKitView`/`AndroidView` 传 `gestureRecognizers`，例如塞一个 `EagerGestureRecognizer`（**立刻赢下竞技场**，触摸全部归原生），或只声明特定类型的 recognizer 做精细划分。

**Q4. 为什么每个视图实例要一条独立的方法通道？`viewId` 从哪来？**

因为一个页面可能同时嵌**多个同类原生视图**（两张地图、三个 WebView），共用一条应用级 channel 就无法寻址"reload 哪一个"。所以通道名带 `viewId`：`com.wenbo.native_lab/native_view_<viewId>`。

`viewId` 由框架在创建视图时分配，Dart 侧从 `onPlatformViewCreated: (int id)` 回调拿到，据此为该实例建控制器。**这是 PlatformView 和前五课"一个 App 一条桥"最大的结构差异。**

**Q5. `creationParams` 和创建后的方法通道有什么区别？codec 为什么必须对齐？**

`creationParams` 是**创建那一刻**的一次性单向初始参数（初始地图区域、初始 URL）；方法通道是**创建之后**的持续双向控制。

codec 对齐是因为 `creationParams` 要跨语言序列化：Dart 用 `StandardMessageCodec` 编，原生 Factory 的 `createArgsCodec()` 必须是**同一套**（iOS `FlutterStandardMessageCodec.sharedInstance()` / Android `StandardMessageCodec.INSTANCE`），否则解不出来。本质就是 L2 那句话：**编解码两端必须同一套规则。**

**Q6. PlatformView 的生命周期怎么管？放进 `ListView` 里会有什么问题？**

原生视图随 widget 的挂载/卸载创建和销毁，销毁时**必须释放原生资源**（Android 的 `dispose()` 里 `webView.destroy()`、iOS 侧断开 delegate、停掉地图定位等），否则泄漏。

放进长列表是**典型反模式**：列表滚动会不断创建/销毁原生视图，每次都要走完整的注册-创建-合成流程，卡顿和内存抖动都很明显。真要做（比如信息流里的广告位），常见对策是**限制同屏实例数 + 复用 + 滚动时先占位、停下再真正加载**。

**Q7. 地图/WebView 这种需求，自己写 PlatformView 还是用现成插件？**

**优先用成熟插件**（`webview_flutter`、各家地图官方 Flutter 插件）。因为它们已经处理掉了 PlatformView 最脏的部分：合成模式适配、手势冲突、键盘与输入法、无障碍、生命周期与内存、双端 API 对齐。

自己写的合理场景：① 公司内部/小众的**原生 SDK 视图**（自研播放器、广告 SDK、硬件预览）；② 现成插件缺关键能力且不便改造。答题时给出这个判断标准，比单纯说"我自己实现过"更成熟。

**Q8. PlatformView 的效果怎么测试？为什么不能靠 widget test？**

widget test 跑在没有原生宿主的纯 Dart 环境，`MKMapView`/`WebView` 根本不会被创建（还得 mock 掉 `flutter/platform_views` 系统通道免得抛错）。所以分层测：

- **widget test 测 Dart 侧**：控制器有没有把动作编成正确的 method call、按平台有没有产出正确的 `UiKitView`/`AndroidView`、页面能不能 build；
- **原生渲染与交互靠模拟器/真机实跑 + 截图**；
- 性能则用 **DevTools / Xcode Instruments** 看合成开销和帧率。

答"原生渲染归实跑、Dart 逻辑归单测，各管一段"，比说"这个测不了"要好。
