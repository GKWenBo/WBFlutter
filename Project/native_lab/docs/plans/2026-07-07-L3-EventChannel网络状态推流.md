# NativeLab L3：EventChannel 原生持续推流 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **教学项目特别说明**：本计划的"执行"是一堂课——边写边讲（iOS 类比先行）。真机验证需学员在模拟器上操作（本课可切 Mac Wi-Fi 开关看状态实时翻动）。

**Goal:** 从"一问一答"的 MethodChannel 升级到"持续推流"的 **EventChannel**。吃透 **EventChannel = 原生侧的一条 Stream**：Dart 侧 `receiveBroadcastStream()` 拿到 `Stream`，原生侧实现 `FlutterStreamHandler` 的 `onListen`/`onCancel`，靠 `EventSink` 把源源不断的事件推给 Dart。用**网络状态监听**（弱网提示/断网重连，电商必备）落地，并讲透订阅生命周期与 iOS `NotificationCenter`/`Combine` 的对应。

**场景（企业真实）：** App 全局监听网络变化——断网弹"网络不可用"、切到蜂窝提示"当前非 Wi-Fi"、恢复自动重连。这类"状态会变、要持续收"的需求，正是 EventChannel 的主场（MethodChannel 只能你问一次它答一次，做不了"变了就通知你"）。

**Architecture:** 沿用分层。Dart 侧 `NetworkBridge`（包一条 `EventChannel`，把原生推的 String 状态 `map` 成强类型 `NetworkStatus` 枚举）+ L3 页面（`StreamBuilder` 实时显示）；iOS 侧 `NetworkStatusStreamHandler`（`NWPathMonitor` 监听，回调里往 sink 推），经 `AnalyticsBridge` 同款并列注册；Android 侧 `ConnectivityManager.NetworkCallback` 对照。**现在 App 挂三条 channel（device_info / analytics / network_status），注册并列追加。**

**Tech Stack:** `EventChannel` + `receiveBroadcastStream()`；`FlutterStreamHandler`(`onListen`/`onCancel`) + `FlutterEventSink`；iOS `Network.framework`(`NWPathMonitor`)。测试用 flutter_test 的 **`setMockStreamHandler` + `MockStreamHandler.inline`**（EventChannel 版的 mock，MethodChannel 的 `setMockMethodCallHandler` 对它不适用）。

## Global Constraints（沿用，每任务默认遵守）

- 新 channel 名 `com.wenbo.native_lab/network_status`，三端逐字符一致。
- 代码注释：详细中文 + iOS 类比；`flutter analyze` 0 issue；全量 `flutter test` 通过。
- git：只 add `native_lab/`；一课一提交，提交前等学员确认过关。
- 验证：iPhone 17 模拟器（bundle id `com.wenbo.nativeLab`）。本课特有验证手段：**切换 Mac Wi-Fi 开/关**（模拟器走宿主网络），看页面 banner 从"Wi-Fi 已连接"实时翻到"无网络连接"。

---

### Task 1: Dart 桥接层（TDD）—— EventChannel = Stream

**Files:**
- Create: `native_lab/app/lib/lessons/l3/network_status.dart`
- Create: `native_lab/app/lib/lessons/l3/network_bridge.dart`
- Test: `native_lab/app/test/l3_network_test.dart`

**Interfaces:**
- Produces: `enum NetworkStatus { wifi, cellular, none, unknown }`（`fromRaw(String?)` + `label`）；`class NetworkBridge`（`static const EventChannel channel`、`static Stream<NetworkStatus> statusStream()`）。

- [ ] **Step 1: 写失败的测试** `test/l3_network_test.dart`

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_lab/lessons/l3/network_bridge.dart';
import 'package:native_lab/lessons/l3/network_status.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // EventChannel 的 mock：不同于 MethodChannel 的 setMockMethodCallHandler，
  // 流用 setMockStreamHandler + MockStreamHandler.inline，在 onListen 里往 sink 推事件。
  void mockStream(MockStreamHandler? handler) {
    binding.defaultBinaryMessenger
        .setMockStreamHandler(NetworkBridge.channel, handler);
  }

  tearDown(() => mockStream(null));

  test('纯映射：字符串 → NetworkStatus 枚举，未知落 unknown', () {
    expect(NetworkStatus.fromRaw('wifi'), NetworkStatus.wifi);
    expect(NetworkStatus.fromRaw('cellular'), NetworkStatus.cellular);
    expect(NetworkStatus.fromRaw('none'), NetworkStatus.none);
    expect(NetworkStatus.fromRaw('foobar'), NetworkStatus.unknown);
    expect(NetworkStatus.fromRaw(null), NetworkStatus.unknown);
  });

  test('状态流：原生推的字符串序列被映射成枚举序列', () async {
    mockStream(MockStreamHandler.inline(onListen: (args, events) {
      // 原生"持续推"的模拟：连推三条再结束。
      events.success('wifi');
      events.success('cellular');
      events.success('none');
      events.endOfStream();
    }));

    final statuses = await NetworkBridge.statusStream().toList();
    expect(statuses, [
      NetworkStatus.wifi,
      NetworkStatus.cellular,
      NetworkStatus.none,
    ]);
  });

  test('原生 error 事件在 Dart 流里表现为 PlatformException', () async {
    mockStream(MockStreamHandler.inline(onListen: (args, events) {
      events.error(code: 'MONITOR_FAILED', message: '网络监听启动失败');
    }));

    expect(
      NetworkBridge.statusStream(),
      emitsError(isA<PlatformException>()
          .having((e) => e.code, 'code', 'MONITOR_FAILED')),
    );
  });
}
```

- [ ] **Step 2: 跑测试确认失败**
Run: `cd /Users/wenbo/Desktop/WBFlutter/native_lab/app && flutter test test/l3_network_test.dart`
Expected: FAIL，`network_bridge.dart` 不存在。

- [ ] **Step 3: 实现枚举与桥**

`lib/lessons/l3/network_status.dart`：

```dart
/// 网络状态强类型枚举。原生推来的是裸字符串，进业务层前先收口成枚举，
/// 别让 'wifi'/'none' 这种魔法字符串在 UI 代码里到处比对。
enum NetworkStatus {
  wifi,
  cellular,
  none,
  unknown;

  /// 原生 → Dart 的收口。未知值一律落 unknown（桥接层要宽容，同 L1/L2）。
  factory NetworkStatus.fromRaw(String? raw) => switch (raw) {
        'wifi' => NetworkStatus.wifi,
        'cellular' => NetworkStatus.cellular,
        'none' => NetworkStatus.none,
        _ => NetworkStatus.unknown,
      };

  /// UI 展示文案。
  String get label => switch (this) {
        NetworkStatus.wifi => 'Wi-Fi 已连接',
        NetworkStatus.cellular => '蜂窝网络',
        NetworkStatus.none => '无网络连接',
        NetworkStatus.unknown => '未知状态',
      };
}
```

`lib/lessons/l3/network_bridge.dart`：

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'network_status.dart';

/// L3 网络状态桥（Dart 侧）。第三条 channel，且是第一条 EventChannel。
/// 心智模型：EventChannel 就是"原生侧的一条 Stream"——
/// receiveBroadcastStream() 一订阅，原生的 onListen 就被触发开始推；
/// 取消订阅，原生的 onCancel 被触发去拆监听。
class NetworkBridge {
  NetworkBridge._();

  @visibleForTesting
  static const EventChannel channel =
      EventChannel('com.wenbo.native_lab/network_status');

  /// 订阅网络状态流。原生持续推字符串，这里 map 成强类型枚举交给 UI。
  /// broadcast = 多个监听者共享同一条原生流（对比 single-subscription）。
  static Stream<NetworkStatus> statusStream() {
    return channel
        .receiveBroadcastStream()
        .map((raw) => NetworkStatus.fromRaw(raw as String?));
  }
}
```

- [ ] **Step 4: 跑测试确认通过**
Run: `flutter test test/l3_network_test.dart`
Expected: `All tests passed!`（3 个）。零原生代码——`setMockStreamHandler` 顶替了原生推流。

---

### Task 2: L3 页面（StreamBuilder）+ 注册表解锁

**Files:**
- Create: `native_lab/app/lib/lessons/l3/l3_network_page.dart`
- Modify: `native_lab/app/lib/lessons/lesson_registry.dart`（L3 `locked`→`inProgress` + pageBuilder + import）
- Modify: `native_lab/app/test/lesson_list_test.dart`（锁定样本 L3 → L4）
- Modify: `native_lab/app/test/l3_network_test.dart`（追加页面 widget test）

**Interfaces:**
- Consumes: Task 1 的 `NetworkBridge.statusStream()`、`NetworkStatus`
- Produces: `class L3NetworkPage`；registry L3 `inProgress`

- [ ] **Step 1: 改门禁测试 + 追加页面测试**

`test/lesson_list_test.dart` 锁定样本换 L4：

```dart
  testWidgets('点击锁定课时只弹提示，不跳转', (tester) async {
    await tester.pumpWidget(const NativeLabApp());
    await tester.tap(find.text('页面级混合 + 权限'));
    await tester.pump();
    expect(find.text('先完成前面的课时，再解锁 L4'), findsOneWidget);
  });
```

`test/l3_network_test.dart` 末尾追加（import material + l3_network_page）：

```dart
  testWidgets('L3 页面：StreamBuilder 随原生推送更新状态', (tester) async {
    mockStream(MockStreamHandler.inline(onListen: (args, events) {
      events.success('wifi');
    }));
    await tester.pumpWidget(const MaterialApp(home: L3NetworkPage()));
    await tester.pump(); // 让 stream 首个事件到达并重建
    expect(find.text('Wi-Fi 已连接'), findsOneWidget);
  });

  testWidgets('L3 页面：断网时展示无网络文案', (tester) async {
    mockStream(MockStreamHandler.inline(onListen: (args, events) {
      events.success('none');
    }));
    await tester.pumpWidget(const MaterialApp(home: L3NetworkPage()));
    await tester.pump();
    expect(find.text('无网络连接'), findsOneWidget);
  });
```

- [ ] **Step 2: 跑测试确认失败**（`l3_network_page.dart` 不存在）

- [ ] **Step 3: 实现页面** `lib/lessons/l3/l3_network_page.dart`

用 `StreamBuilder<NetworkStatus>` 订阅 `NetworkBridge.statusStream()`：根据 `snapshot.hasError` 展示错误条；根据 `snapshot.data` 展示带颜色的状态 banner（wifi 绿 / cellular 橙 / none 红 / 其它灰）+ `status.label`。页面用 `StatelessWidget` 即可（StreamBuilder 自己管订阅）。教学注释点明：**StreamBuilder 在 initState 时订阅（触发原生 onListen）、dispose 时自动取消（触发原生 onCancel）**——订阅生命周期被 Flutter 框架托管了。

- [ ] **Step 4: registry 解锁 L3**

```dart
  Lesson(
    id: 'L3',
    title: 'EventChannel：原生持续推流',
    scenario: '网络状态监听（弱网提示、断网重连）',
    status: LessonStatus.inProgress,
    pageBuilder: (_) => const L3NetworkPage(),
  ),
```
（头部加 import；去掉 `const`。）

- [ ] **Step 5: 全量测试 + analyze**
Expected: 全过（现有 16 + L3 的 3 桥 + 2 页面 = 21），`No issues found!`。

---

### Task 3: iOS Swift 侧实现 + 模拟器验证

**Files:**
- Modify: `native_lab/app/ios/Runner/AppDelegate.swift`（并列注册第三条 channel + NetworkBridge/StreamHandler）

**Interfaces:**
- Consumes: Task 1 契约（EventChannel `com.wenbo.native_lab/network_status`，推 `"wifi"`/`"cellular"`/`"none"` 字符串）
- Produces: 真机可用的原生监听

- [ ] **Step 1: 注册处并列加一段**（`didInitializeImplicitFlutterEngine` 内）

```swift
    NetworkBridge.register(messenger: engineBridge.applicationRegistrar.messenger())
```

- [ ] **Step 2: 新增 NetworkBridge + StreamHandler**（AppDelegate.swift 内，import Network）

```swift
import Network

/// L3 网络状态桥（原生侧）。EventChannel 的原生端 = 一个 FlutterStreamHandler。
enum NetworkBridge {
  // 保持强引用：StreamHandler 持有 NWPathMonitor，别让它被释放。
  private static var handler: NetworkStatusStreamHandler?

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterEventChannel(
      name: "com.wenbo.native_lab/network_status", // 三端一致
      binaryMessenger: messenger)
    let h = NetworkStatusStreamHandler()
    channel.setStreamHandler(h)
    handler = h
  }
}

/// 订阅生命周期对照 iOS：onListen ≈ addObserver / Combine sink，
/// onCancel ≈ removeObserver / AnyCancellable.cancel()。
final class NetworkStatusStreamHandler: NSObject, FlutterStreamHandler {
  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "com.wenbo.native_lab.netmonitor")

  // Dart 侧一 listen，这里就被调用：拿到 sink，开始把事件往里推。
  func onListen(withArguments arguments: Any?,
                eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    monitor.pathUpdateHandler = { path in
      let status: String
      if path.status == .satisfied {
        status = path.usesInterfaceType(.wifi) ? "wifi" : "cellular"
      } else {
        status = "none"
      }
      // NWPathMonitor 回调在后台队列，事件必须回主线程投递给 sink。
      DispatchQueue.main.async { events(status) }
    }
    monitor.start(queue: queue)
    return nil
  }

  // Dart 侧取消订阅（StreamBuilder dispose）：拆掉监听，别泄漏。
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    monitor.cancel()
    return nil
  }
}
```

- [ ] **Step 3: 构建安装启动**

```bash
cd /Users/wenbo/Desktop/WBFlutter/native_lab/app
flutter build ios --simulator
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl terminate booted com.wenbo.nativeLab 2>/dev/null
xcrun simctl launch booted com.wenbo.nativeLab
```

- [ ] **Step 4: 学员上手验证**
进 L3：初始应显示绿色 **Wi-Fi 已连接**。然后**关掉 Mac 的 Wi-Fi**（模拟器走宿主网络）→ banner 实时翻到红色 **无网络连接**；再打开 → 自动回到 Wi-Fi。这就是 EventChannel"变了就推、无需轮询"的价值。截图 `xcrun simctl io booted screenshot /tmp/l3_result.png` 存档。

---

### Task 4: Android Kotlin 对照实现

**Files:**
- Modify: `native_lab/app/android/app/src/main/kotlin/com/wenbo/native_lab/MainActivity.kt`（追加 EventChannel）

**Interfaces:**
- Consumes: Task 1 契约（同 channel 名，推同样的状态字符串）
- Produces: Android 对照（讲解为主，不强制跑安卓）

- [ ] **Step 1: 追加 network_status EventChannel**（configureFlutterEngine 内）

```kotlin
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.wenbo.native_lab/network_status"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            private var callback: ConnectivityManager.NetworkCallback? = null
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                val cb = object : ConnectivityManager.NetworkCallback() {
                    // 回调在非主线程，事件要 runOnUiThread 投递（同 iOS 回主线程）。
                    override fun onAvailable(network: Network) {
                        runOnUiThread { events.success("wifi") }
                    }
                    override fun onLost(network: Network) {
                        runOnUiThread { events.success("none") }
                    }
                }
                cm.registerDefaultNetworkCallback(cb)
                callback = cb
            }
            override fun onCancel(arguments: Any?) {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                callback?.let { cm.unregisterNetworkCallback(it) }
                callback = null
            }
        })
```

- [ ] **Step 2: 讲解双端差异**（写进课时文档"双端对照"）
① 监听 API：iOS `NWPathMonitor`(Network.framework) vs Android `ConnectivityManager.NetworkCallback`；② 生命周期命名：两端都叫 onListen/onCancel（Flutter 统一），底层分别 start/cancel monitor 与 register/unregister callback；③ 线程：两端回调都在后台，都要切主线程投 sink；④ 权限：Android 需 `ACCESS_NETWORK_STATE`（讲到即可，教学不强跑）。

---

### Task 5: 课时文档 + 进度表 + 学员自测

**Files:**
- Create: `native_lab/docs/lessons/L3-EventChannel网络状态推流.md`
- Modify: `native_lab/docs/lessons/README.md`（L3 → 🔵 进行中 + 链接）

- [ ] **Step 1: 写课时文档**（六段模板，核心 = EventChannel 生命周期 + 与 MethodChannel 对比）

1. **本课要掌握什么**：EventChannel = 原生侧一条 Stream；`onListen`/`onCancel` 生命周期与 Dart 订阅/取消的对应；EventSink 持有与线程（回主线程投递）；error 事件；与 MethodChannel 的选型（一问一答 vs 持续推）。
2. **★ MethodChannel vs EventChannel 对比表**：调用模型、Dart API（invokeMethod vs receiveBroadcastStream）、原生 API（setMethodCallHandler vs setStreamHandler）、返回（Future vs Stream）、典型场景。
3. **控件/API 速查表**：Dart `EventChannel`/`receiveBroadcastStream`/`StreamBuilder`；Swift `FlutterEventChannel`/`FlutterStreamHandler`/`FlutterEventSink`/`NWPathMonitor`；各配 iOS 类比（NotificationCenter/Combine）+ 坑（sink 回主线程、handler 强引用、忘 onCancel 泄漏）。
4. **代码地图**：l3/ 三文件 + AppDelegate 的 NetworkBridge/StreamHandler + MainActivity 的 EventChannel。
5. **双端对照**：Task 4 Step 2 四点成表。
6. **自测清单**：① EventChannel 和 MethodChannel 何时用哪个？② onListen/onCancel 分别在 Dart 侧什么动作时被触发？对应 iOS 的什么？③ 为什么 sink 回调要切回主线程？不切会怎样？④ StreamBuilder 帮你管了订阅的哪两件事？
7. **课后练习**：给状态流加一个"信号强度"字段——把推的 `String` 换成 `Map{'type':..., 'level':int}`（复用 L2 的编解码），Dart 侧模型扩展 + 补一条 mock 流测试。

- [ ] **Step 2: 更新进度表** README L3 → 🔵 进行中 + 链接。
- [ ] **Step 3: 学员过自测清单**（四题答疑到"过了"）。

---

### Task 6: 过关翻牌 + 提交（等学员确认后才执行）

**Files:**
- Modify: `native_lab/docs/lessons/README.md`（L3 🔵 → ✅）
- Modify: `native_lab/app/lib/lessons/lesson_registry.dart`（L3 `inProgress` → `done`）

- [ ] **Step 1: 翻状态**（两处）
- [ ] **Step 2: 全量质量门** `flutter analyze && flutter test`（21 测全过 + 0 issue）
- [ ] **Step 3: 提交**
```bash
cd /Users/wenbo/Desktop/WBFlutter && git add native_lab/
git commit -m "L3 EventChannel 网络状态推流：Stream + onListen/onCancel + NWPathMonitor"
```

---

## Self-Review 记录

- 覆盖检查：设计文档 L3 三知识点——EventChannel=Stream（Task 1 statusStream + Task 2 StreamBuilder）、onListen/onCancel（Task 3 StreamHandler + 文档生命周期）、对比 NotificationCenter/Combine（Task 3 注释 + 文档速查表）全部落地；企业场景（网络监听）即页面功能。
- 一致性检查：channel 名 `com.wenbo.native_lab/network_status` 四处一致；状态字符串 `wifi`/`cellular`/`none` 三端一致；测试计数 3 桥 + 2 页面 = 5 新增，叠加 16 → 21。
- 新 API 检查：EventChannel 的 mock 用 `setMockStreamHandler`/`MockStreamHandler.inline`（非 MethodChannel 的 setMockMethodCallHandler）——已在 Task 1 测试点明。
- 三 channel 检查：iOS 注册处三行并列、Android 三块并列，互不覆盖。
- 占位符检查：无 TBD。
```
