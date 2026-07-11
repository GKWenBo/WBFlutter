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
