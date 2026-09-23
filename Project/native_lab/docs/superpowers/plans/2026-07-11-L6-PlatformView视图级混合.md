# L6 PlatformView 视图级混合 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Flutter 页面里嵌入原生视图（iOS=MKMapView / Android=WebView），教学 PlatformView 的嵌入机制、创建参数传递、以及"每实例一条方法通道"。

**Architecture:** Dart 侧一个按平台分发的 `NativePlatformView` widget（`UiKitView`/`AndroidView`），通过 `creationParams` 传初始状态；原生侧各注册一个 Factory 产出包原生视图的 PlatformView，并在 `onPlatformViewCreated` 得到的 viewId 上各挂一条方法通道供 Flutter 控制。

**Tech Stack:** Flutter (UiKitView/AndroidView/MethodChannel)、iOS Swift (FlutterPlatformViewFactory + MapKit)、Android Kotlin (PlatformViewFactory + android.webkit.WebView)。

## Global Constraints

- viewType 两端一致：`com.wenbo.native_lab/native_view`（copy 到三端逐字符一致）。
- 每实例方法通道名：`com.wenbo.native_lab/native_view_<viewId>`（viewId 来自 onPlatformViewCreated）。
- 创建参数 codec：Dart 用 `StandardMessageCodec`，iOS 用 `FlutterStandardMessageCodec.sharedInstance()`，Android 用 `StandardMessageCodec.INSTANCE`。
- 只嵌一个实例；不引入任何地图/网页第三方 SDK 或 API key；不做 Android Google Maps。
- 教学注释规范：iOS(Swift) 主讲 + Kotlin 对照，中文详注带 iOS 类比（沿用 L1–L5）。
- 只 `git add native_lab/` 路径；提交信息以 `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` 收尾。
- 命令一律以 `cd /Users/wenbo/Desktop/WBFlutter/native_lab/app &&` 前缀（shell cwd 会重置）。
- README 翻 ✅ 与"L6 完成"提交在**过关四件套 + 学员口头确认**后才做（Task 6）。

## File Structure

- `app/lib/lessons/l6/native_platform_view.dart` — 嵌入 widget + 每实例控制器（纯 Dart，可单测）。
- `app/lib/lessons/l6/l6_platform_view_page.dart` — 页面：原生视图 + 控制条 + 说明卡。
- `app/ios/Runner/MapPlatformView.swift` — iOS Factory + PlatformView(MKMapView) + 方法通道。
- `app/android/app/src/main/kotlin/com/wenbo/native_lab/WebPlatformView.kt` — Android Factory + PlatformView(WebView) + 方法通道。
- 改：`app/lib/lessons/lesson_registry.dart`、`app/test/lesson_list_test.dart`、`app/ios/Runner/AppDelegate.swift`、`app/ios/Runner.xcodeproj/project.pbxproj`、`app/android/app/src/main/kotlin/com/wenbo/native_lab/MainActivity.kt`、`app/android/app/src/main/AndroidManifest.xml`。
- 文档：`docs/lessons/L6-PlatformView视图级混合.md`、`docs/lessons/自测答案/L6-自测答案.md`、`docs/lessons/README.md`。

---

### Task 1: Dart 嵌入 widget + 每实例控制器

**Files:**
- Create: `app/lib/lessons/l6/native_platform_view.dart`
- Test: `app/test/l6_native_view_test.dart`

**Interfaces:**
- Produces:
  - `const String kNativeViewType = 'com.wenbo.native_lab/native_view';`
  - `class NativeViewController { NativeViewController(int viewId, {BinaryMessenger? messenger}); Future<void> setMapType(String type); Future<void> resetRegion(); Future<void> reload(); Future<void> loadUrl(String url); }`
  - `class NativePlatformView extends StatelessWidget { const NativePlatformView({Key? key, required Map<String, dynamic> creationParams, required void Function(NativeViewController) onCreated}); }`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/l6_native_view_test.dart
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_lab/lessons/l6/native_platform_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('控制器把按钮动作编码成对应的 method call', () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('com.wenbo.native_lab/native_view_7');
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final c = NativeViewController(7);
    await c.setMapType('satellite');
    await c.resetRegion();
    await c.loadUrl('https://dart.dev');
    await c.reload();

    expect(calls[0].method, 'setMapType');
    expect(calls[0].arguments, 'satellite');
    expect(calls[1].method, 'resetRegion');
    expect(calls[2].method, 'loadUrl');
    expect(calls[2].arguments, 'https://dart.dev');
    expect(calls[3].method, 'reload');
  });

  testWidgets('按平台产出对应的原生视图 widget', (tester) async {
    // 拦截 flutter/platform_views 系统通道：让 create 返回一个 viewId，
    // 避免 UiKitView/AndroidView 在无原生宿主的测试环境里抛错。
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => call.method == 'create' ? 0 : null,
    );
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null));

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: NativePlatformView(
        creationParams: const {'lat': 31.0, 'lng': 121.0, 'span': 0.2},
        onCreated: (_) {},
      ),
    ));
    expect(find.byType(UiKitView), findsOneWidget);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: NativePlatformView(
        creationParams: const {'url': 'https://flutter.dev'},
        onCreated: (_) {},
      ),
    ));
    expect(find.byType(AndroidView), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/wenbo/Desktop/WBFlutter/native_lab/app && flutter test test/l6_native_view_test.dart`
Expected: FAIL（`native_platform_view.dart` 不存在 / 符号未定义）。

- [ ] **Step 3: Write minimal implementation**

```dart
// app/lib/lessons/l6/native_platform_view.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// PlatformView 的类型标识：Dart 按它嵌入，两端 factory 按它注册（逐字符一致）。
const String kNativeViewType = 'com.wenbo.native_lab/native_view';

/// 每个原生视图【实例】的控制器。关键认知差异：L1–L5 是应用级单例 channel，
/// 这里每个实例一条 channel（用 onPlatformViewCreated 给的 viewId 区分），
/// 因为一个页面可能同时嵌多个同类原生视图，得能分别寻址。
class NativeViewController {
  NativeViewController(int viewId, {BinaryMessenger? messenger})
      : _channel = MethodChannel(
          'com.wenbo.native_lab/native_view_$viewId',
          const StandardMethodCodec(),
          messenger,
        );

  final MethodChannel _channel;

  // iOS 地图控制
  Future<void> setMapType(String type) =>
      _channel.invokeMethod('setMapType', type); // 'standard' | 'satellite'
  Future<void> resetRegion() => _channel.invokeMethod('resetRegion');

  // Android WebView 控制
  Future<void> reload() => _channel.invokeMethod('reload');
  Future<void> loadUrl(String url) => _channel.invokeMethod('loadUrl', url);
}

/// 嵌入原生视图的 widget：按平台分发到 UiKitView / AndroidView。
/// 机制两端一致（同一个 viewType、同一套 creationParams），
/// 但各端 factory 产出的原生视图不同（iOS=MKMapView，Android=WebView）。
class NativePlatformView extends StatelessWidget {
  const NativePlatformView({
    super.key,
    required this.creationParams,
    required this.onCreated,
  });

  /// 创建时一次性传给原生的初始状态（Dart→原生），走 StandardMessageCodec 编码。
  final Map<String, dynamic> creationParams;

  /// 原生视图创建完成回调：拿到 viewId → 造一个绑定该实例的控制器交给页面。
  final void Function(NativeViewController) onCreated;

  @override
  Widget build(BuildContext context) {
    const codec = StandardMessageCodec();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: kNativeViewType,
        creationParams: creationParams,
        creationParamsCodec: codec,
        onPlatformViewCreated: (id) => onCreated(NativeViewController(id)),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // 本课 WebView 只做加载+reload、无文本输入，普通 AndroidView（虚拟显示）够用；
      // 涉及键盘/输入等场景才需切 hybrid composition（PlatformViewLink 那套样板）。
      return AndroidView(
        viewType: kNativeViewType,
        creationParams: creationParams,
        creationParamsCodec: codec,
        onPlatformViewCreated: (id) => onCreated(NativeViewController(id)),
      );
    }
    return const Center(child: Text('该平台不支持原生视图嵌入'));
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/wenbo/Desktop/WBFlutter/native_lab/app && flutter test test/l6_native_view_test.dart`
Expected: PASS（2 tests）。

- [ ] **Step 5: Commit**

```bash
cd /Users/wenbo/Desktop/WBFlutter/native_lab && git add app/lib/lessons/l6/native_platform_view.dart app/test/l6_native_view_test.dart && git commit -m "$(printf 'L6：Dart 嵌入 widget + 每实例控制器\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 2: L6 页面 + 注册表上架 + 锁定测试顺移

**Files:**
- Create: `app/lib/lessons/l6/l6_platform_view_page.dart`
- Modify: `app/lib/lessons/lesson_registry.dart:55-60`（L6 由 locked → done+pageBuilder；见注）
- Modify: `app/test/lesson_list_test.dart:19-23`（锁定样本 L6→L7）

**Interfaces:**
- Consumes: `NativePlatformView`, `NativeViewController`（Task 1）。
- Produces: `class L6PlatformViewPage extends StatefulWidget { const L6PlatformViewPage({Key? key}); }`

> 注：注册表状态本任务先设 `LessonStatus.inProgress`（可进入但 README 仍 ⬜），过关后 Task 6 再翻 done。但 `lesson_list_test` 的"锁定样本"只要 L6 不再是 locked 就得顺移到 L7，所以本任务一起改。

- [ ] **Step 1: Write the failing test（页面冒烟 + 列表锁定顺移）**

改 `app/test/lesson_list_test.dart` 的第二个 test（锁定样本换成 L7），并新增页面冒烟 test：

```dart
// 修改 app/test/lesson_list_test.dart 里 '点击锁定课时只弹提示' 这个 test：
  testWidgets('点击锁定课时只弹提示，不跳转', (tester) async {
    await tester.pumpWidget(const NativeLabApp());
    // L6 已解锁，锁定样本换成 L7。
    await tester.tap(find.text('插件开发'));
    await tester.pump();
    expect(find.text('先完成前面的课时，再解锁 L7'), findsOneWidget);
  });
```

```dart
// 新增 app/test/l6_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_lab/lessons/l6/l6_platform_view_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  testWidgets('L6 页面能 build 并显示标题与控制条', (tester) async {
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => call.method == 'create' ? 0 : null,
    );
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null));

    await tester.pumpWidget(const MaterialApp(home: L6PlatformViewPage()));
    expect(find.text('L6 PlatformView 视图级混合'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/wenbo/Desktop/WBFlutter/native_lab/app && flutter test test/l6_page_test.dart test/lesson_list_test.dart`
Expected: FAIL（`l6_platform_view_page.dart` 不存在；lesson_list_test 里 L6 仍 locked → tap '插件开发' 找不到 SnackBar 文案）。

- [ ] **Step 3a: 写页面实现**

```dart
// app/lib/lessons/l6/l6_platform_view_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'native_platform_view.dart';

/// L6 入口页：把原生视图嵌进 Flutter 页面（视图级混合）。
/// 对照 L4 页面级混合：L4 是"整屏交给原生 VC/Activity，结果回传后就退出"；
/// L6 是"原生视图作为一个 widget 长在 Flutter 布局里，和 Flutter 控件同屏共存"。
class L6PlatformViewPage extends StatefulWidget {
  const L6PlatformViewPage({super.key});

  @override
  State<L6PlatformViewPage> createState() => _L6PlatformViewPageState();
}

class _L6PlatformViewPageState extends State<L6PlatformViewPage> {
  NativeViewController? _controller; // 原生视图创建后才有（onCreated 回填）
  final bool _isAndroid = defaultTargetPlatform == TargetPlatform.android;

  // 创建参数按平台给：iOS 传地图初始区域，Android 传初始 URL。
  Map<String, dynamic> get _creationParams => _isAndroid
      ? const {'url': 'https://flutter.dev'}
      : const {'lat': 31.2304, 'lng': 121.4737, 'span': 0.2}; // 上海

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('L6 PlatformView 视图级混合')),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _isAndroid
                    ? '下方是嵌进来的【原生 WebView】。同一套 PlatformView 机制，'
                        'iOS 那端嵌的是真 MKMapView——嵌什么原生视图是各端自己的事。'
                    : '下方是嵌进来的【真 MKMapView】。它作为一个 widget 长在 Flutter '
                        '布局里，和上面的说明卡、下面的按钮同屏共存（对照 L4 的整屏接管）。',
              ),
            ),
          ),
          // 原生视图占据主要空间。Expanded 给它一个有界高度（PlatformView 需要确定尺寸）。
          Expanded(
            child: NativePlatformView(
              creationParams: _creationParams,
              onCreated: (c) => _controller = c,
            ),
          ),
          _ControlBar(isAndroid: _isAndroid, controllerOf: () => _controller),
        ],
      ),
    );
  }
}

/// 控制条：按平台显示对应按钮，点击走【每实例方法通道】驱动原生视图。
class _ControlBar extends StatelessWidget {
  const _ControlBar({required this.isAndroid, required this.controllerOf});

  final bool isAndroid;
  final NativeViewController? Function() controllerOf;

  @override
  Widget build(BuildContext context) {
    final buttons = isAndroid
        ? [
            FilledButton.tonal(
              onPressed: () => controllerOf()?.reload(),
              child: const Text('Reload'),
            ),
            FilledButton.tonal(
              onPressed: () => controllerOf()?.loadUrl('https://dart.dev'),
              child: const Text('换到 dart.dev'),
            ),
          ]
        : [
            FilledButton.tonal(
              onPressed: () => controllerOf()?.setMapType('standard'),
              child: const Text('标准'),
            ),
            FilledButton.tonal(
              onPressed: () => controllerOf()?.setMapType('satellite'),
              child: const Text('卫星'),
            ),
            FilledButton.tonal(
              onPressed: () => controllerOf()?.resetRegion(),
              child: const Text('回到初始点'),
            ),
          ];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(spacing: 12, runSpacing: 8, children: buttons),
    );
  }
}
```

- [ ] **Step 3b: 注册表上架**

改 `app/lib/lessons/lesson_registry.dart`：顶部加 `import 'l6/l6_platform_view_page.dart';`；把 L6 那条从

```dart
  const Lesson(
    id: 'L6',
    title: 'PlatformView：视图级混合',
    scenario: '页面里嵌原生地图 MKMapView',
    status: LessonStatus.locked,
  ),
```

改成

```dart
  Lesson(
    id: 'L6',
    title: 'PlatformView：视图级混合',
    scenario: 'iOS 嵌真地图 / Android 嵌 WebView',
    status: LessonStatus.inProgress,
    pageBuilder: (_) => const L6PlatformViewPage(),
  ),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/wenbo/Desktop/WBFlutter/native_lab/app && flutter test test/l6_page_test.dart test/lesson_list_test.dart && flutter analyze lib/lessons/l6`
Expected: 全 PASS，analyze `No issues found!`。

- [ ] **Step 5: Commit**

```bash
cd /Users/wenbo/Desktop/WBFlutter/native_lab && git add app/lib/lessons/l6/l6_platform_view_page.dart app/lib/lessons/lesson_registry.dart app/test/lesson_list_test.dart app/test/l6_page_test.dart && git commit -m "$(printf 'L6：页面 + 注册表上架 + 锁定测试顺移到 L7\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 3: iOS 原生侧（MapPlatformView + 注册 + pbxproj）

**Files:**
- Create: `app/ios/Runner/MapPlatformView.swift`
- Modify: `app/ios/Runner/AppDelegate.swift:34-38`（在 L5 注册后追加 Factory 注册）
- Modify: `app/ios/Runner.xcodeproj/project.pbxproj`（手动加新 .swift，同 L5 做法）

**Interfaces:**
- Consumes: viewType `com.wenbo.native_lab/native_view`、每实例通道 `com.wenbo.native_lab/native_view_<id>`（Task 1 契约）。
- Produces: `MapViewFactory`（供 AppDelegate 注册）。

> 无法单测（原生视图）。验证 = iOS 模拟器编译 + 截图（Task 6）。

- [ ] **Step 1: 写 MapPlatformView.swift**

```swift
// app/ios/Runner/MapPlatformView.swift
import Flutter
import MapKit
import UIKit

/// PlatformView 工厂：Flutter 每嵌一个 viewType=native_view 的视图，就调一次 create。
/// 对照 L1–L5 的 register(messenger:)：那是一条应用级 channel；这里是"按需产出视图实例"。
final class MapViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }

  // 创建参数用标准消息 codec 解码——必须和 Dart 侧 StandardMessageCodec 对齐。
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    MapPlatformView(frame: frame, viewId: viewId, args: args, messenger: messenger)
  }
}

/// 单个嵌入的地图实例：持有 MKMapView + 一条【本实例专属】方法通道。
final class MapPlatformView: NSObject, FlutterPlatformView {
  private let mapView = MKMapView()
  private let initialRegion: MKCoordinateRegion

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    // 读创建参数（Dart 传来的初始区域）。数字过 codec 是 NSNumber → as? Double 取。
    let dict = args as? [String: Any]
    let lat = dict?["lat"] as? Double ?? 31.2304
    let lng = dict?["lng"] as? Double ?? 121.4737
    let span = dict?["span"] as? Double ?? 0.2
    initialRegion = MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
      span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))
    super.init()
    mapView.frame = frame
    mapView.setRegion(initialRegion, animated: false)

    // 每实例一条通道：名字带 viewId，页面里多个视图各走各的（对照应用级单例 channel）。
    let channel = FlutterMethodChannel(
      name: "com.wenbo.native_lab/native_view_\(viewId)", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "setMapType":
        // 标准 ↔ 卫星（对照 Dart 的 setMapType('standard'|'satellite')）。
        self.mapView.mapType = (call.arguments as? String) == "satellite" ? .satellite : .standard
        result(nil)
      case "resetRegion":
        self.mapView.setRegion(self.initialRegion, animated: true)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // FlutterPlatformView 协议：把要嵌进 Flutter 的 UIView 交出去。
  func view() -> UIView { mapView }
}
```

- [ ] **Step 2: AppDelegate 注册 Factory**

在 `app/ios/Runner/AppDelegate.swift` 的 `didInitializeImplicitFlutterEngine` 里、L5 注册块之后追加：

```swift
    // 第六条：L6 PlatformView——注册【视图工厂】（不是 channel）。
    // registrar.register(factory, withId:) 把 viewType 和工厂绑定，
    // Dart 侧 UiKitView(viewType:) 就能按名产出 MKMapView 实例。
    let l6Registrar = engineBridge.applicationRegistrar
    l6Registrar.register(
      MapViewFactory(messenger: l6Registrar.messenger()),
      withId: "com.wenbo.native_lab/native_view")
```

- [ ] **Step 3: pbxproj 手动加文件**

本工程无 FileSystemSynchronized groups，需手动加 4 处（镜像 L5 的 `DeviceInfoMessages.g.swift`，用新 ID `A1B2C3D40000000000000601`=fileRef、`A1B2C3D40000000000000602`=buildFile）：
1. PBXBuildFile：`A1B2C3D40000000000000602 /* MapPlatformView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1B2C3D40000000000000601 /* MapPlatformView.swift */; };`
2. PBXFileReference：`A1B2C3D40000000000000601 /* MapPlatformView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MapPlatformView.swift; sourceTree = "<group>"; };`
3. Runner group 的 children 数组里加 `A1B2C3D40000000000000601 /* MapPlatformView.swift */,`
4. Sources build phase 的 files 数组里加 `A1B2C3D40000000000000602 /* MapPlatformView.swift in Sources */,`

（定位锚点：搜索 `DeviceInfoMessages.g.swift` 的 4 处出现，在每处旁边并列插入。）

- [ ] **Step 4: 验证 iOS 编译（arm64-only 绕过 Xcode 27 lipo 坑）**

先 `cd /Users/wenbo/Desktop/WBFlutter/native_lab/app && flutter build ios --config-only` 刷新，再用已记的 arm64-only 方案编译（见 memory `env-xcode27-lipo-simulator`）。
Expected: 编译成功，无 Swift 报错。（真机嵌图/截图在 Task 6 统一做。）

- [ ] **Step 5: Commit**

```bash
cd /Users/wenbo/Desktop/WBFlutter/native_lab && git add app/ios/ && git commit -m "$(printf 'L6：iOS MapPlatformView（MKMapView 工厂 + 每实例方法通道）\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 4: Android 原生侧（WebPlatformView + 注册 + INTERNET 权限）

**Files:**
- Create: `app/android/app/src/main/kotlin/com/wenbo/native_lab/WebPlatformView.kt`
- Modify: `app/android/app/src/main/kotlin/com/wenbo/native_lab/MainActivity.kt`（configureFlutterEngine 末尾注册工厂）
- Modify: `app/android/app/src/main/AndroidManifest.xml`（加 INTERNET 权限）

**Interfaces:**
- Consumes: viewType、每实例通道名（Task 1 契约）。
- Produces: `WebViewFactory`（供 MainActivity 注册）。

> 按惯例 Android 不编译，只保证与 iOS 概念对齐、代码正确。

- [ ] **Step 1: 写 WebPlatformView.kt**

```kotlin
// app/android/app/src/main/kotlin/com/wenbo/native_lab/WebPlatformView.kt
package com.wenbo.native_lab

import android.content.Context
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/// PlatformView 工厂（对照 iOS 的 MapViewFactory）。createArgsCodec = StandardMessageCodec，
/// 必须和 Dart 侧对齐。Flutter 每嵌一个 native_view，就调一次 create 产出一个实例。
class WebViewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return WebPlatformView(context, viewId, args, messenger)
    }
}

/// 单个嵌入的 WebView 实例 + 本实例专属方法通道（对照 iOS 的 MapPlatformView）。
class WebPlatformView(
    context: Context,
    viewId: Int,
    args: Any?,
    messenger: BinaryMessenger,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val webView = WebView(context)

    init {
        webView.webViewClient = WebViewClient() // 链接在本 WebView 内打开，不外跳浏览器
        webView.settings.javaScriptEnabled = true
        // 读创建参数里的初始 URL（对照 iOS 读初始地图区域）。
        val url = (args as? Map<*, *>)?.get("url") as? String ?: "https://flutter.dev"
        webView.loadUrl(url)

        // 每实例一条通道：名字带 viewId（对照 iOS 同名规则）。
        MethodChannel(messenger, "com.wenbo.native_lab/native_view_$viewId")
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "reload" -> { webView.reload(); result.success(null) }
            "loadUrl" -> {
                val url = call.arguments as? String
                if (url != null) { webView.loadUrl(url); result.success(null) }
                else result.error("BAD_ARGS", "loadUrl 需要 String", null)
            }
            else -> result.notImplemented()
        }
    }

    override fun getView() = webView
    override fun dispose() { webView.destroy() }
}
```

- [ ] **Step 2: MainActivity 注册工厂**

在 `app/android/app/src/main/kotlin/com/wenbo/native_lab/MainActivity.kt` 的 `configureFlutterEngine` 末尾（L5 的 `DeviceInfoHostApi.setUp(...)` 之后）追加：

```kotlin
        // L6 PlatformView：注册【视图工厂】（不是 channel）。对照 iOS 的 registrar.register(_:withId:)。
        // registry.registerViewFactory(viewType, factory) 把 viewType 和工厂绑定，
        // Dart 侧 AndroidView(viewType:) 就能按名产出 WebView 实例。
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "com.wenbo.native_lab/native_view",
            WebViewFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
```

- [ ] **Step 3: AndroidManifest 加 INTERNET 权限**

在 `app/android/app/src/main/AndroidManifest.xml` 的 `<manifest>` 标签内、`<application>` 之前加（WebView 加载 https 页需要）：

```xml
    <uses-permission android:name="android.permission.INTERNET"/>
```

- [ ] **Step 4: 静态校验（不编译 Android）**

人工核对：包名、viewType 字符串、通道名与 iOS/Dart 逐字符一致；`WebViewFactory` 构造签名与 MainActivity 调用一致。

- [ ] **Step 5: Commit**

```bash
cd /Users/wenbo/Desktop/WBFlutter/native_lab && git add app/android/ && git commit -m "$(printf 'L6：Android WebPlatformView（WebView 工厂 + 每实例方法通道）+ INTERNET 权限\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 5: 课程文档（L6 讲义 + 自测答案）

**Files:**
- Create: `docs/lessons/L6-PlatformView视图级混合.md`
- Create: `docs/lessons/自测答案/L6-自测答案.md`

**Interfaces:** 无代码接口。文档须在 Task 6 让学员验收前存在（硬规则）。

- [ ] **Step 1: 写 L6 讲义（7 段式，沿用 L5 结构）**

按既有 7 段模板写 `docs/lessons/L6-PlatformView视图级混合.md`：① 本课掌握什么；② API 速查表（`kNativeViewType`/`UiKitView`/`AndroidView`/`creationParams`/`onPlatformViewCreated`/`FlutterPlatformViewFactory`/`PlatformViewFactory`/每实例通道名）；③ 代码地图（Dart 侧 native_platform_view.dart+页面；iOS MapPlatformView.swift+AppDelegate 注册；Android WebPlatformView.kt+MainActivity 注册+Manifest）；④ 测试（原生视图不可单测 → 只测控制器编码+页面冒烟，含 platform_views 通道 mock 的原因）；⑤ 双端对照（iOS UiKitView+MKMapView vs Android AndroidView+WebView；应用级单例 channel vs 每实例通道；hybrid composition 何时需要）；⑥ 自测清单（viewType 三端一致？creationParams codec 为何要对齐？每实例通道为何带 viewId？PlatformView vs L4 页面级混合怎么选？性能代价来自哪？）；⑦ 课后练习（反向回调：iOS regionDidChange 回报中心坐标 / Android onPageFinished 回报标题，显示到控制条）。

- [ ] **Step 2: 写自测答案**

`docs/lessons/自测答案/L6-自测答案.md`：逐条回答 ⑥ 的自测清单。要点：性能代价来自"原生视图与 Flutter 渲染树合成（纹理拷贝/额外图层）"，故仅在需要真实原生 SDK 视图时才用；PlatformView 用于"原生视图与 Flutter 同屏共存/局部嵌入"，L4 页面级混合用于"整屏交给原生、拿结果即退"。

- [ ] **Step 3: Commit**

```bash
cd /Users/wenbo/Desktop/WBFlutter/native_lab && git add docs/lessons/L6-PlatformView视图级混合.md "docs/lessons/自测答案/L6-自测答案.md" && git commit -m "$(printf 'L6 讲义 + 自测答案\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 6: 过关验收 + README 翻 ✅

**Files:**
- Modify: `docs/lessons/README.md:15`（L6 ⬜→✅）
- Modify: `app/lib/lessons/lesson_registry.dart`（L6 `inProgress`→`done`）

**Interfaces:** 无。这是四件套过关闸门。

- [ ] **Step 1: 全量校验**

Run:
```
cd /Users/wenbo/Desktop/WBFlutter/native_lab/app && flutter analyze && flutter test
```
Expected: analyze `No issues found!`；test 全过。

- [ ] **Step 2: 模拟器实跑截图**

用 arm64-only 方案在 iPhone 模拟器跑起来，进 L6：确认地图嵌入显示、标准/卫星切换生效、回到初始点生效。截图留证。

- [ ] **Step 3: 学员口头确认**

请学员过 L6 讲义 ⑥ 自测清单并口头确认过关。**未确认不翻状态。**

- [ ] **Step 4: 翻状态**

- `docs/lessons/README.md` L6 行 `⬜ 未开始`→`✅ 已完成`。
- `lesson_registry.dart` L6 的 `status: LessonStatus.inProgress`→`LessonStatus.done`。

- [ ] **Step 5: Commit**

```bash
cd /Users/wenbo/Desktop/WBFlutter/native_lab && git add app/lib/lessons/lesson_registry.dart docs/lessons/README.md && git commit -m "$(printf 'NativeLab L6 完成：PlatformView 视图级混合（iOS 真地图 / Android WebView）\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

## Self-Review

**Spec coverage：**
- 场景/交互（创建参数 + 每实例方法通道）→ Task 1（控制器/widget）、Task 2（页面控制条）、Task 3/4（原生实现）。✅
- iOS 真地图 / Android WebView 不对称 → Task 3 / Task 4。✅
- viewType/通道命名/codec 对齐 → Global Constraints + 各任务代码。✅
- 每实例通道 vs 应用级单例的认知差异 → Task 1 注释 + Task 5 讲义 ⑤。✅
- hybrid composition 取舍 → Task 1 注释 + Task 5 讲义。✅
- 性能代价 / 与 L4 选型 → Task 5 讲义 ⑤⑥ + 自测答案。✅
- 测试（控制器编码 + 页面冒烟 + 锁定顺移）→ Task 1、Task 2。✅
- 课后练习（反向回调）→ Task 5 ⑦。✅
- 进度 plumbing（注册表/README/lock 测试）→ Task 2 + Task 6。✅
- INTERNET 权限（WebView 必需）→ Task 4 Step 3。✅

**Placeholder scan：** 无 TBD/TODO；每个代码步骤含完整代码。✅

**Type consistency：** `NativeViewController(int viewId, {BinaryMessenger? messenger})`、`setMapType/resetRegion/reload/loadUrl`、`NativePlatformView({creationParams, onCreated})`、`kNativeViewType`、通道名 `com.wenbo.native_lab/native_view_<id>`、viewType `com.wenbo.native_lab/native_view` 在 Task 1/2/3/4 全对齐。✅
