# NativeLab L1：MethodChannel 设备信息桥 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **教学项目特别说明**：本计划的"执行"是一堂课——边写边讲（iOS 类比先行），验证截图给学员看。真机效果验证需要学员在模拟器上亲手点按钮，届时截图确认。

**Goal:** 第一段真正的 channel 代码：Flutter 通过 MethodChannel 调 Swift 读设备信息（机型/系统/App 版本）和电池电量，三类失败路径（error/notImplemented/未注册）全部有企业级处理，Dart 侧用 mock 单测覆盖。

**Architecture:** Dart 侧 `DeviceInfoBridge`（静态方法包一条 `MethodChannel`）+ `DeviceInfo` 模型 + L1 页面；iOS 侧 `DeviceInfoBridge` enum 写在 AppDelegate.swift 内（pbxproj 是老式 objectVersion 54，避免手改工程文件，L7 抽插件时搬家），经 `engineBridge.applicationRegistrar.messenger()` 注册——这是新模板官方留给"应用级 channel"的口子；Android 侧 MainActivity `configureFlutterEngine` 对照实现。

**Tech Stack:** MethodChannel + StandardMethodCodec（默认）；测试用 `TestDefaultBinaryMessengerBinding` mock 原生响应。

## Global Constraints（沿用 L0，每任务默认遵守）

- channel 名统一 `com.wenbo.native_lab/device_info`（企业惯例：反域名 + 功能名，Dart/Swift/Kotlin 三处必须逐字符一致）。
- 代码注释：详细中文 + iOS 类比；`flutter analyze` 0 issue；全量 `flutter test` 通过。
- git：只 add `native_lab/`；一课一提交，提交前等学员确认过关。
- 验证：iPhone 17 模拟器（bundle id `com.wenbo.nativeLab`），截图 `xcrun simctl io booted screenshot`。

---

### Task 1: Dart 桥接层（TDD）

**Files:**
- Create: `native_lab/app/lib/lessons/l1/device_info.dart`
- Create: `native_lab/app/lib/lessons/l1/device_info_bridge.dart`
- Test: `native_lab/app/test/l1_device_info_test.dart`

**Interfaces:**
- Consumes: 无
- Produces: `class DeviceInfo`（`String model, systemName, systemVersion, appVersion`，`DeviceInfo.fromMap(Map<String, Object?>)`）；`class DeviceInfoBridge`（`static const MethodChannel channel`、`static Future<DeviceInfo> fetchDeviceInfo()`、`static Future<int> fetchBatteryLevel()`）。Task 2 的页面、Task 3 的 Swift 侧都对着这套契约写。

- [ ] **Step 1: 写失败的测试**

`test/l1_device_info_test.dart`：

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_lab/lessons/l1/device_info_bridge.dart';

void main() {
  // channel 通信要走 binary messenger，测试环境得先把 binding 立起来。
  // iOS 类比：跑 XCTest 前得有个宿主 App 环境，一个意思。
  TestWidgetsFlutterBinding.ensureInitialized();

  // 小工具：把"假装自己是原生侧"的 handler 挂到我们的 channel 上。
  void mockNative(Future<Object?>? Function(MethodCall call)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceInfoBridge.channel, handler);
  }

  tearDown(() => mockNative(null)); // 每条测试后拆掉 mock，互不污染

  test('getDeviceInfo：成功解析原生返回的 Map', () async {
    mockNative((call) async {
      expect(call.method, 'getDeviceInfo');
      return {
        'model': 'iPhone',
        'systemName': 'iOS',
        'systemVersion': '19.0',
        'appVersion': '1.0.0',
      };
    });
    final info = await DeviceInfoBridge.fetchDeviceInfo();
    expect(info.model, 'iPhone');
    expect(info.systemName, 'iOS');
    expect(info.appVersion, '1.0.0');
  });

  test('原生 result.error 在 Dart 侧变成 PlatformException', () async {
    mockNative((call) async {
      throw PlatformException(code: 'UNAVAILABLE', message: '模拟器没有电池');
    });
    await expectLater(
      DeviceInfoBridge.fetchBatteryLevel(),
      throwsA(isA<PlatformException>()
          .having((e) => e.code, 'code', 'UNAVAILABLE')),
    );
  });

  test('原生侧没注册 handler 时抛 MissingPluginException', () async {
    // 故意不挂 mock == 原生侧没人认领这条 channel（热重启后忘注册就是这景象）
    await expectLater(
      DeviceInfoBridge.fetchBatteryLevel(),
      throwsA(isA<MissingPluginException>()),
    );
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd /Users/wenbo/Desktop/WBFlutter/native_lab/app && flutter test test/l1_device_info_test.dart`
Expected: FAIL，报 `device_info_bridge.dart` 不存在。

- [ ] **Step 3: 实现模型与桥**

`lib/lessons/l1/device_info.dart`：

```dart
/// 设备信息模型（企业场景：风控/日志上报的标配字段）。
/// 教学点：channel 传回来的是 Map，进业务层前先收口成强类型，
/// 别让 Map<String, dynamic> 在业务代码里到处漂。
class DeviceInfo {
  const DeviceInfo({
    required this.model,
    required this.systemName,
    required this.systemVersion,
    required this.appVersion,
  });

  /// 解析原生传来的 Map。字段缺失给兜底值而不是崩——
  /// 双端实现难免有出入，桥接层要宽容（对比：业务真身数据不吞错）。
  factory DeviceInfo.fromMap(Map<String, Object?> map) {
    return DeviceInfo(
      model: map['model'] as String? ?? 'unknown',
      systemName: map['systemName'] as String? ?? 'unknown',
      systemVersion: map['systemVersion'] as String? ?? 'unknown',
      appVersion: map['appVersion'] as String? ?? 'unknown',
    );
  }

  final String model;
  final String systemName;
  final String systemVersion;
  final String appVersion;
}
```

`lib/lessons/l1/device_info_bridge.dart`：

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_info.dart';

/// L1 设备信息桥（Dart 侧）。
/// iOS 类比：可以把 MethodChannel 想成一条命名的 XPC/消息通道——
/// 两端约好频道名和方法名（字符串），中间走二进制编解码（StandardMethodCodec）。
class DeviceInfoBridge {
  DeviceInfoBridge._(); // 纯静态入口，不给实例化（API 设计的取舍 L7 再展开）

  /// 频道名：反域名 + 功能名，Dart/Swift/Kotlin 三处必须逐字符一致。
  /// 这就是手写 channel 的"魔法字符串"痛点，L5 用 Pigeon 消灭它。
  @visibleForTesting
  static const MethodChannel channel =
      MethodChannel('com.wenbo.native_lab/device_info');

  /// 拉一次设备信息。
  /// invokeMapMethod 比 invokeMethod 多做一步 Map 的类型收窄
  /// （原生传来的其实是 Map<Object?, Object?>）。
  static Future<DeviceInfo> fetchDeviceInfo() async {
    final map = await channel.invokeMapMethod<String, Object?>('getDeviceInfo');
    if (map == null) {
      // 原生 result(nil) 的场景：给出可定位的错误而不是空指针崩溃。
      throw PlatformException(code: 'NULL_RESULT', message: '原生侧返回了空数据');
    }
    return DeviceInfo.fromMap(map);
  }

  /// 电池电量（0-100）。原生侧拿不到时会 result.error(UNAVAILABLE)，
  /// 在 Dart 这边表现为 PlatformException——调用方自己决定怎么兜底。
  static Future<int> fetchBatteryLevel() async {
    final level = await channel.invokeMethod<int>('getBatteryLevel');
    return level ?? -1;
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/l1_device_info_test.dart`
Expected: `All tests passed!`（3 个）。注意此时**没写一行 Swift**，测试就能全绿——这就是 mock 掉原生侧的意义（CI 上不起模拟器也能跑）。

---

### Task 2: L1 页面 + 注册表解锁

**Files:**
- Create: `native_lab/app/lib/lessons/l1/l1_device_info_page.dart`
- Modify: `native_lab/app/lib/lessons/lesson_registry.dart`（L1 解锁）
- Modify: `native_lab/app/test/lesson_list_test.dart`（门禁测试改指向 L2）
- Modify: `native_lab/app/test/l1_device_info_test.dart`（追加页面 widget test）

**Interfaces:**
- Consumes: Task 1 的 `DeviceInfoBridge.fetchDeviceInfo()/fetchBatteryLevel()`、`DeviceInfo`
- Produces: `class L1DeviceInfoPage extends StatefulWidget`；registry 里 L1 `status: inProgress` + `pageBuilder`

- [ ] **Step 1: 改门禁测试（L1 即将解锁，锁定样本换 L2）**

`test/lesson_list_test.dart` 里"点击锁定课时"一条改为：

```dart
  testWidgets('点击锁定课时只弹提示，不跳转', (tester) async {
    await tester.pumpWidget(const NativeLabApp());
    await tester.tap(find.text('数据编解码与复杂参数'));
    await tester.pump(); // 推一帧，让 SnackBar 开始入场
    expect(find.text('先完成前面的课时，再解锁 L2'), findsOneWidget);
  });
```

追加页面测试到 `test/l1_device_info_test.dart` 末尾（`main` 内）：

```dart
  testWidgets('L1 页面：点按钮展示设备信息', (tester) async {
    mockNative((call) async => {
          'model': 'iPhone',
          'systemName': 'iOS',
          'systemVersion': '19.0',
          'appVersion': '1.0.0',
        });
    await tester.pumpWidget(const MaterialApp(home: L1DeviceInfoPage()));
    await tester.tap(find.text('获取设备信息'));
    await tester.pumpAndSettle();
    expect(find.text('iPhone'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
  });

  testWidgets('L1 页面：原生报错时展示错误条', (tester) async {
    mockNative((call) async {
      throw PlatformException(code: 'UNAVAILABLE', message: '模拟器没有电池');
    });
    await tester.pumpWidget(const MaterialApp(home: L1DeviceInfoPage()));
    await tester.tap(find.text('获取电池电量'));
    await tester.pumpAndSettle();
    expect(find.textContaining('UNAVAILABLE'), findsOneWidget);
  });
```

（对应 import 加 `package:flutter/material.dart` 与 `package:native_lab/lessons/l1/l1_device_info_page.dart`。）

- [ ] **Step 2: 跑测试确认新用例失败**

Run: `flutter test test/l1_device_info_test.dart`
Expected: FAIL，`l1_device_info_page.dart` 不存在。

- [ ] **Step 3: 实现页面**

`lib/lessons/l1/l1_device_info_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'device_info.dart';
import 'device_info_bridge.dart';

/// L1 入口页：设备信息桥的演示台。
/// 企业场景里这些数据会静默上报；教学页面把它可视化。
class L1DeviceInfoPage extends StatefulWidget {
  const L1DeviceInfoPage({super.key});

  @override
  State<L1DeviceInfoPage> createState() => _L1DeviceInfoPageState();
}

class _L1DeviceInfoPageState extends State<L1DeviceInfoPage> {
  DeviceInfo? _info;
  int? _battery;
  String? _error;

  Future<void> _loadDeviceInfo() async {
    // 教学点：只 catch 具体异常，不写宽 catch（WanShop M9 的老规矩）。
    try {
      final info = await DeviceInfoBridge.fetchDeviceInfo();
      if (!mounted) return; // await 之后碰 State 前先查 mounted（M10 老规矩）
      setState(() {
        _info = info;
        _error = null;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _error = '原生返回错误：${e.code}｜${e.message}');
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _error = '原生侧没注册这条 channel（去查 AppDelegate）');
    }
  }

  Future<void> _loadBattery() async {
    try {
      final battery = await DeviceInfoBridge.fetchBatteryLevel();
      if (!mounted) return;
      setState(() {
        _battery = battery;
        _error = null;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _error = '原生返回错误：${e.code}｜${e.message}');
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _error = '原生侧没注册这条 channel（去查 AppDelegate）');
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Scaffold(
      appBar: AppBar(title: const Text('L1 设备信息桥')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton(
            onPressed: _loadDeviceInfo,
            child: const Text('获取设备信息'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _loadBattery,
            child: const Text('获取电池电量'),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!),
              ),
            ),
          if (info != null) ...[
            ListTile(title: const Text('机型'), trailing: Text(info.model)),
            ListTile(title: const Text('系统'), trailing: Text(info.systemName)),
            ListTile(
              title: const Text('系统版本'),
              trailing: Text(info.systemVersion),
            ),
            ListTile(
              title: const Text('App 版本'),
              trailing: Text(info.appVersion),
            ),
          ],
          if (_battery != null)
            ListTile(title: const Text('电池电量'), trailing: Text('$_battery%')),
        ],
      ),
    );
  }
}
```

`lesson_registry.dart` 里 L1 那条改为：

```dart
  Lesson(
    id: 'L1',
    title: 'MethodChannel：Flutter 调原生',
    scenario: '设备信息上报（机型/系统版本/电池）',
    status: LessonStatus.inProgress,
    pageBuilder: (_) => const L1DeviceInfoPage(),
  ),
```

（文件头部加 `import 'l1/l1_device_info_page.dart';`，L1 这条去掉 `const`。）

- [ ] **Step 4: 全量测试 + analyze**

Run: `flutter test && flutter analyze`
Expected: 8 个测试全过（3 列表 + 3 桥 + 2 页面），`No issues found!`。

---

### Task 3: iOS Swift 侧实现 + 模拟器验证

**Files:**
- Modify: `native_lab/app/ios/Runner/AppDelegate.swift`

**Interfaces:**
- Consumes: Task 1 定的契约（channel 名 `com.wenbo.native_lab/device_info`，方法 `getDeviceInfo` 返回 Map、`getBatteryLevel` 返回 Int 或 error(UNAVAILABLE)）
- Produces: 真机可用的原生实现

- [ ] **Step 1: 改 AppDelegate.swift（整文件替换）**

```swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // 应用级 channel 的官方注册口：applicationRegistrar 提供 binaryMessenger。
    // （插件走 pluginRegistry，应用自己的桥走这里——头文件注释原话就是
    //  "application-level method channels"。）
    DeviceInfoBridge.register(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// L1 设备信息桥（原生侧）。
/// 暂与 AppDelegate 同文件：往 Runner 加新 .swift 要动 pbxproj，
/// L7 抽成插件时它会搬进独立工程。用无 case 的 enum 当命名空间，防误实例化。
enum DeviceInfoBridge {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.wenbo.native_lab/device_info", // 与 Dart 侧逐字符一致
      binaryMessenger: messenger)
    channel.setMethodCallHandler(handle)
  }

  private static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // 这个回调跑在 Platform 线程 == iOS 主线程（L0 的线程模型落地了）。
    switch call.method {
    case "getDeviceInfo":
      let device = UIDevice.current
      let appVersion =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
      // 直接 result(字典)：StandardMethodCodec 自动把 Dictionary/String
      // 编解码成 Dart 的 Map/String（类型映射表 L2 展开）。
      result([
        "model": device.model,
        "systemName": device.systemName,
        "systemVersion": device.systemVersion,
        "appVersion": appVersion,
      ])
    case "getBatteryLevel":
      let device = UIDevice.current
      device.isBatteryMonitoringEnabled = true
      let level = device.batteryLevel
      if level < 0 {
        // 拿不到就明说（模拟器没有电池，batteryLevel 恒为 -1）——
        // 企业规矩：给 Dart 侧结构化错误码，不要静默塞假数据。
        result(FlutterError(
          code: "UNAVAILABLE",
          message: "拿不到电量（模拟器没有电池）",
          details: nil))
      } else {
        result(Int(level * 100))
      }
    default:
      // 方法名对不上：Dart 侧收到 MissingPluginException 的近亲——
      // FlutterMethodNotImplemented，防止两端方法清单悄悄漂移。
      result(FlutterMethodNotImplemented)
    }
  }
}
```

- [ ] **Step 2: 构建安装启动**

```bash
cd /Users/wenbo/Desktop/WBFlutter/native_lab/app
flutter build ios --simulator
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl terminate booted com.wenbo.nativeLab 2>/dev/null
xcrun simctl launch booted com.wenbo.nativeLab
```

Expected: 构建成功、App 启动、首页 L1 变为播放图标（已解锁）。

- [ ] **Step 3: 学员上手验证（本课的"跑通"时刻）**

学员在模拟器上：点 L1 →「获取设备信息」应显示 iPhone/iOS/版本号/1.0.0；「获取电池电量」应显示红色错误条 `UNAVAILABLE｜拿不到电量（模拟器没有电池）`——这不是 bug，是模拟器限定的预期行为，真机上会显示真实电量。学员停在结果页，执行 `xcrun simctl io booted screenshot /tmp/l1_result.png` 截图存档确认。

---

### Task 4: Android Kotlin 对照实现

**Files:**
- Modify: `native_lab/app/android/app/src/main/kotlin/com/wenbo/native_lab/MainActivity.kt`

**Interfaces:**
- Consumes: Task 1 的契约（同一 channel 名、同两个方法）
- Produces: Android 对照实现（讲解为主，不强制跑安卓模拟器——设计文档决策）

- [ ] **Step 1: 改 MainActivity.kt（整文件替换）**

```kotlin
package com.wenbo.native_lab

import android.content.Context
import android.os.BatteryManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // 对照 iOS：configureFlutterEngine ≈ didInitializeImplicitFlutterEngine，
    // 都是"引擎就绪，来挂你的 channel"的回调。
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.wenbo.native_lab/device_info" // 三端逐字符一致
        ).setMethodCallHandler { call, result ->
            // 这里跑在 Android 主线程（= Platform 线程），与 iOS 同款约定。
            when (call.method) {
                "getDeviceInfo" -> result.success(
                    mapOf(
                        "model" to Build.MODEL,
                        "systemName" to "Android",
                        "systemVersion" to Build.VERSION.RELEASE,
                        "appVersion" to (packageManager
                            .getPackageInfo(packageName, 0).versionName ?: "unknown"),
                    )
                )
                "getBatteryLevel" -> {
                    val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                    val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                    if (level < 0) {
                        result.error("UNAVAILABLE", "拿不到电量", null)
                    } else {
                        result.success(level)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
```

- [ ] **Step 2: 讲解双端差异**

对照点（写进课时文档"双端对照"节）：注册时机（configureFlutterEngine vs didInitializeImplicitFlutterEngine）；messenger 获取（`flutterEngine.dartExecutor.binaryMessenger` vs `applicationRegistrar.messenger()`）；错误返回（`result.error(code,msg,details)` 三参 vs `FlutterError(code:message:details:)`）；Android 模拟器电池返回 50/100 不报 UNAVAILABLE（AVD 模拟了电池，与 iOS 模拟器行为不同）。

---

### Task 5: 课时文档 + 进度表 + 学员自测

**Files:**
- Create: `native_lab/docs/lessons/L1-MethodChannel设备信息桥.md`
- Modify: `native_lab/docs/lessons/README.md`（L1 行：⬜ → 🔵 进行中，并加文档链接）

**Interfaces:**
- Consumes: Task 1–4 的全部代码（代码地图要写实际路径）
- Produces: L1 课时文档；学员过完自测即满足过关条件第 4 项

- [ ] **Step 1: 写课时文档**（六段模板，本课具体内容）

1. **本课要掌握什么**：MethodChannel 的完整生命周期（Dart invokeMethod → 编码 → Platform 线程 handler → result → 解码回 Future）；三类失败路径及企业处理（error→PlatformException、notImplemented→MissingPluginException 近亲、未注册→MissingPluginException）；为什么桥接层要收口成强类型模型；mock 测试让 channel 代码不起模拟器就能进 CI。
2. **控件/API 速查表**：Dart 侧 MethodChannel/invokeMethod/invokeMapMethod/PlatformException/MissingPluginException/@visibleForTesting/TestDefaultBinaryMessengerBinding；Swift 侧 FlutterMethodChannel/FlutterResult/FlutterError/FlutterMethodNotImplemented/applicationRegistrar；每项 iOS 类比 + 用法 + 坑。
3. **代码地图**：l1/ 三个 Dart 文件 + AppDelegate.swift + MainActivity.kt 各自职责。
4. **双端对照**：Task 4 Step 2 的四个对照点成表。
5. **自测清单**：① channel 名在几个地方出现、错一个字符会发生什么（现象是哪种异常）？② result.error 在 Dart 侧变成什么？怎么写 catch？③ 原生 handler 跑在哪条线程？能直接做耗时 IO 吗？④ 为什么 Dart 侧测试不起模拟器也能测 channel？mock 挂在哪一层？
6. **课后练习**：给桥加一个 `getSystemUptime`（开机时长，`ProcessInfo.processInfo.systemUptime`），三端各改一处 + 补一条 mock 单测。

- [ ] **Step 2: 更新进度表**

README.md L1 行改为：`| [L1](L1-MethodChannel设备信息桥.md) | MethodChannel：Flutter 调原生 | 🔵 进行中 |`

- [ ] **Step 3: 学员过自测清单**

四道题发给学员，答疑到全部过关，学员说"过了"为止。

---

### Task 6: 过关翻牌 + 提交（等学员确认后才执行）

**Files:**
- Modify: `native_lab/docs/lessons/README.md`（L1 🔵 → ✅ 已完成）
- Modify: `native_lab/app/lib/lessons/lesson_registry.dart`（L1 `inProgress` → `done`）

**Interfaces:**
- Consumes: 学员的口头过关确认
- Produces: L1 完成态仓库快照，L2 开课起点

- [ ] **Step 1: 翻状态**（两处，如上）

- [ ] **Step 2: 全量质量门**

Run: `cd /Users/wenbo/Desktop/WBFlutter/native_lab/app && flutter analyze && flutter test`
Expected: `No issues found!` + 8 个测试全过。

- [ ] **Step 3: 提交**

```bash
cd /Users/wenbo/Desktop/WBFlutter
git add native_lab/
git commit -m "L1 MethodChannel 设备信息桥：Flutter 调原生 + 三类异常处理 + mock 单测"
```

---

## Self-Review 记录

- 覆盖检查：设计文档 L1 行的四个知识点（MethodChannel、result 三态、回调线程、Dart 侧单测）分别落在 Task 1/3（channel 与 result）、Task 3 Step 1 注释与文档（线程）、Task 1（mock 单测）；企业场景（设备信息上报）即页面功能。
- 占位符检查：无 TBD；文档任务给的是具体内容清单。
- 一致性检查：channel 名 `com.wenbo.native_lab/device_info` 在 Dart/Swift/Kotlin/测试四处一致；方法名 `getDeviceInfo`/`getBatteryLevel` 一致；`DeviceInfoBridge.channel` 的 `@visibleForTesting` 与测试引用一致；测试计数 3+3+2=8。
