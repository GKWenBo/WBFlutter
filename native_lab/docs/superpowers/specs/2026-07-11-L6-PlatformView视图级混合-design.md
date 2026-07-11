# L6 设计：PlatformView 视图级混合

- 状态：已定稿（brainstorming 通过）
- 日期：2026-07-11
- 上游：[原生交互教学课程设计](../../2026-07-06-原生交互教学课程设计.md) 第 L6 行

## 一句话

在 Flutter 页面里嵌入**原生视图**（iOS = 真 MKMapView / Android = 原生 WebView），
讲透 PlatformView 的嵌入机制、创建参数传递、以及"每个视图实例一条方法通道"
这一与 L1–L5 应用级单例 channel 的关键差异。

## 决策记录（brainstorming 结论）

1. **原生视图选型（不对称，且这是教学点）**
   - iOS：真 `MKMapView`（MapKit 内置、零配置、模拟器可跑，对资深 iOS 零学习成本）。
   - Android：原生 `android.webkit.WebView`（内置、无需密钥，绕开 Google Maps 在国内的 key/Play Services 之痛）。
   - 立意：**PlatformView 机制两端一致（Dart 按 viewType 嵌入），但每端 factory 产出什么原生视图是各自的事**——还原真实开发里"iOS 嵌 MapKit、Android 嵌 WebView/高德"的常态。

2. **交互深度 = ②（嵌入 + 创建参数 + 按实例方法通道）**
   - 反向回调（native→Flutter）不进正课，留作**课后练习**。

## 场景与交互

页面上半区嵌原生视图，下方 Flutter 控制条。

- **创建参数（Flutter → 原生，创建时一次性）**
  - iOS：初始中心坐标 + 缩放（默认上海）。
  - Android：初始 URL（默认 `https://flutter.dev`）。
- **按实例方法通道（Flutter → 原生，创建后）**
  - iOS：「标准 ↔ 卫星」切换、「回到初始点」。
  - Android：「reload」、「加载另一个 URL」。

## PlatformView 机制要点（教学核心，写进课程文档）

- `viewType` 字符串两端一致：`com.wenbo.native_lab/native_view`，Dart 按它嵌入。
- Dart 侧一个 `NativePlatformView` widget，按平台返回 `UiKitView` / `AndroidView`；
  `creationParams` 用 `StandardMessageCodec` 编码传下去。
- 原生侧各注册一个 **Factory**：
  - iOS `FlutterPlatformViewFactory` → 产出包 `MKMapView` 的 `FlutterPlatformView`。
  - Android `PlatformViewFactory` → 产出包 `WebView` 的 `PlatformView`。
- **关键认知差异**：L1–L5 是**应用级单例 channel**；PlatformView 是**每个实例一条 channel**
  （`com.wenbo.native_lab/native_view_<viewId>`，用 viewId 区分），因为一个页面里可能同时存在多个同类原生视图。
- **hybrid composition 取舍**：Android WebView 在本课只做"加载 + reload"、无文本输入，
  普通 `AndroidView`（虚拟显示模式）够用；文档注明"涉及键盘/文本输入等场景何时需切 hybrid composition"，不在正课引入其样板。
- 新版 Flutter 无需再在 Info.plist 配 `io.flutter.embedded_views_preview`（早已移除）。

## 代码地图

**Dart（新增）**
- `lib/lessons/l6/native_platform_view.dart`：嵌入 widget + 每实例控制器（把按钮动作编码成 method call）。
- `lib/lessons/l6/l6_platform_view_page.dart`：页面（原生视图 + 控制条 + 说明卡）。

**iOS（新增/改）**
- `ios/Runner/MapPlatformView.swift`（新增）：`FlutterPlatformViewFactory` + `FlutterPlatformView`（MKMapView）+ 每实例方法通道。
- `ios/Runner/AppDelegate.swift`（改）：注册 Factory（沿用 `applicationRegistrar`）。
- `ios/Runner.xcodeproj/project.pbxproj`（改）：手动加新 .swift（本工程无 synchronized groups，同 L5 做法）。

**Android（新增/改）**
- `android/app/src/main/kotlin/com/wenbo/native_lab/WebPlatformView.kt`（新增）：`PlatformViewFactory` + `PlatformView`（WebView）+ 每实例方法通道。
- `android/app/src/main/kotlin/com/wenbo/native_lab/MainActivity.kt`（改）：`registerViewFactory` 注册。

**进度plumbing（改）**
- `lib/lessons/lesson_registry.dart`：L6 上架、`pageBuilder` 指向 `L6PlatformViewPage`。
- `test/lesson_list_test.dart`：锁定样本从 L6 顺移到 L7。

**课程文档（实现后、验收前创建）**
- `docs/lessons/L6-PlatformView视图级混合.md`（7 段式）+ `docs/lessons/自测答案/L6-自测答案.md`。
- `docs/lessons/README.md`：L6 状态待过关后翻 ✅。

## 测试 & 过关

- PlatformView 的原生视图无法在 widget test 里真渲染 → 只测 Dart 侧可测部分：
  1. 每实例控制器把按钮动作正确编码成 method call（mock method channel 断言）。
  2. 页面能 build 冒烟（不校验原生视图内容）。
- 过关四件套（沿用）：iPhone 模拟器截图 / `flutter analyze` 0 issue / `flutter test` 全过 / 学员口头确认。

## 课后练习

加**反向回调（native → Flutter）**：
- iOS 地图拖动结束回报中心坐标；Android 页面加载完成回报标题。
- 结果显示在 Flutter 控制条上（对照 L3 EventChannel / L5 FlutterApi 的"原生主动回话"）。

## 非目标（YAGNI）

- 不引入任何地图/网页第三方 SDK 或 API key。
- 不做多实例同屏演示（机制上支持，正课只嵌一个）。
- Android 不做 Google Maps；hybrid composition 样板不进正课。
