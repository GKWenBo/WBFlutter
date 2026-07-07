# L1 MethodChannel：设备信息桥

> 企业场景：几乎每个 App 都要上报设备信息（机型/系统版本/App 版本/电池）给风控、日志、统计。这些数据只能从原生拿，Flutter 侧拿不到——于是有了第一座桥：MethodChannel。

## 一、本课要掌握什么

**1. MethodChannel 的完整生命周期（一次调用走了哪些路）。**

```
Dart: channel.invokeMethod('getDeviceInfo')
  → StandardMethodCodec 把 方法名+参数 编码成二进制
  → 通过 BinaryMessenger 跨线程发给原生（UI 线程 → Platform 线程）
原生: setMethodCallHandler 的闭包被调用（在 Platform 线程 = iOS 主线程）
  → 你 result(字典)
  → StandardMethodCodec 把返回值编码回二进制
Dart: invokeMethod 的 Future 完成，拿到解码后的 Map
```

一句话心智模型：**MethodChannel = 一条命名的、带自动编解码的异步 RPC 通道**。iOS 类比：像给两个进程之间架了条约定好方法名的 XPC，只不过这里两端是 Dart 运行时和原生运行时。

**2. 三类失败路径，以及企业里怎么处理（本课的暗线，后面每课沿用）。**

| 原生侧做了什么 | Dart 侧收到什么 | 什么时候发生 | 怎么处理 |
|---|---|---|---|
| `result(FlutterError(code:...))` | `PlatformException`（带 code/message） | 业务失败（如模拟器没电池） | `on PlatformException catch (e)`，按 e.code 兜底 |
| `result(FlutterMethodNotImplemented)` | `MissingPluginException` | 方法名两端对不上 | 说明两端方法清单漂移了，去核对 |
| 根本没 `setMethodCallHandler` | `MissingPluginException` | 原生侧忘注册 / 热重启后没重注册 | 去查 AppDelegate 的注册代码 |

关键认知：**channel 本身没有超时机制**。原生侧不 result，Dart 的 Future 就永远挂着。需要超时就自己包 `.timeout(Duration(...))`（本课没用到，L3/L4 有异步耗时场景时会讲）。

**3. 为什么桥接层要把 Map 收口成强类型模型。**

`invokeMethod` 返回的是 `Map<Object?, Object?>`。如果让它直接流进业务代码，到处都是 `map['model'] as String?`，字段名拼错编译器不管、运行时才崩。所以 `DeviceInfoBridge.fetchDeviceInfo()` 在桥接层就 `DeviceInfo.fromMap` 收口——**桥接层是脏乱的 Map 世界和干净的强类型世界的边界**。

**4. mock 测试：channel 代码不起模拟器也能测。**

`setMockMethodCallHandler` 把"假装是原生侧"的闭包挂到 channel 上，于是 Dart 侧逻辑（编码、解码、异常转换、模型解析）全都能在纯 Dart 测试里跑，CI 上不需要模拟器。这是企业里 channel 代码的标准测法，也是面试高频点。

## 二、控件 / API 速查表

### Dart 侧

| API | iOS 类比 | 用法 & 关键参数 | 易踩的坑 |
|---|---|---|---|
| `MethodChannel(name)` | 一条命名 XPC/通道的句柄 | `const MethodChannel('反域名/功能名')` | 名字两端错一个字符 → `MissingPluginException` |
| `invokeMethod<T>(method, [args])` | 异步 RPC 调用 | 返回 `Future<T?>`，args 只能是 codec 支持的类型 | 返回值可能为 null，要处理 |
| `invokeMapMethod<K,V>(method)` | 同上但收窄成 Map | 省去手动 `.cast()` | 仍可能返回 null |
| `PlatformException` | 带 code 的 NSError | `e.code` / `e.message` / `e.details` | 只 catch 它，别写宽 catch 吞掉别的错 |
| `MissingPluginException` | 方法未实现的信号 | 单独 catch，给"去查注册"的提示 | 热重启后原生没重注册最常见 |
| `@visibleForTesting` | 仅测试可见的标注 | 标在 `channel` 上让测试能引用 | 只是提示，不是强制 private |
| `TestDefaultBinaryMessengerBinding` | XCTest 的测试宿主环境 | `.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, handler)` | 用完 `tearDown` 里置 null，别污染其他用例 |

### Swift 侧

| API | iOS 类比 | 用法 & 关键参数 | 易踩的坑 |
|---|---|---|---|
| `FlutterMethodChannel(name:binaryMessenger:)` | channel 的原生端句柄 | name 与 Dart 一致；messenger 从 registrar 拿 | messenger 来源错了收不到消息 |
| `setMethodCallHandler(_:)` | 注册 RPC 处理闭包 | `(call, result) -> Void` | 每个 result 分支必须调且只调一次 result |
| `FlutterResult` | 回调闭包 | `result(值)` / `result(FlutterError(...))` / `result(FlutterMethodNotImplemented)` | 忘了调 result → Dart 侧 Future 永久挂起 |
| `FlutterError(code:message:details:)` | NSError 的 channel 版 | 业务失败时回传 | code 建议用大写常量串，跨端约定 |
| `FlutterMethodNotImplemented` | "没这方法"哨兵值 | default 分支返回 | 别用 result(nil) 冒充，语义不同 |
| `applicationRegistrar.messenger()` | 应用级 binaryMessenger 来源 | 新模板给"应用自己的 channel"的官方口 | 插件用 pluginRegistry，应用桥用这个 |

## 三、代码地图

```
native_lab/app/lib/lessons/l1/
├── device_info.dart          # DeviceInfo 模型 + fromMap（Map→强类型的收口）
├── device_info_bridge.dart   # DeviceInfoBridge：包一条 MethodChannel，两个静态方法
└── l1_device_info_page.dart  # 演示台：两个按钮 + 三态展示（信息/电池/错误条）

native_lab/app/ios/Runner/AppDelegate.swift
    └── enum DeviceInfoBridge  # 原生侧 handler（暂寄居 AppDelegate 文件，L7 搬去插件）

native_lab/app/android/app/src/main/kotlin/.../MainActivity.kt
    └── configureFlutterEngine # Android 对照实现

native_lab/app/test/l1_device_info_test.dart  # 3 桥单测 + 2 页面 widget test
```

## 四、双端对照

| 对照点 | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| 注册时机 | `didInitializeImplicitFlutterEngine` 回调 | `configureFlutterEngine` 覆写 |
| messenger 来源 | `engineBridge.applicationRegistrar.messenger()` | `flutterEngine.dartExecutor.binaryMessenger` |
| 业务错误返回 | `result(FlutterError(code:message:details:))` | `result.error(code, msg, details)` |
| 未实现返回 | `result(FlutterMethodNotImplemented)` | `result.notImplemented()` |
| 模拟器电池 | 恒 -1 → 触发 UNAVAILABLE（模拟器无电池） | AVD 模拟了电池，通常返回真实百分比、不报错 |

## 五、自测清单

> 参考答案 + 课后练习核对见 [自测答案/L1-自测答案与练习核对.md](自测答案/L1-自测答案与练习核对.md)（建议先自己答，再对照）。

1. channel 名在项目里出现在哪几处？错一个字符会怎样，Dart 侧表现为哪种异常？
2. 原生 `result(FlutterError(...))` 到了 Dart 侧变成什么类型？给出捕获它的那行 catch 怎么写。
3. 原生 handler 跑在哪条线程？如果里面要做耗时磁盘 IO，直接在闭包里做会有什么后果、该怎么办？
4. 为什么 Dart 侧的 3 个桥单测不起模拟器也能跑通？mock 具体挂在哪一层（哪个对象的哪个方法）？

## 六、课后练习

给桥加一个 `getSystemUptime`（系统开机时长秒数）：
- Dart：`DeviceInfoBridge.fetchUptime() -> Future<double>`；
- Swift：`case "getSystemUptime": result(ProcessInfo.processInfo.systemUptime)`；
- Kotlin：`"getSystemUptime" -> result.success(android.os.SystemClock.elapsedRealtime() / 1000.0)`；
- 补一条 mock 单测：mock 返回 12345.0，断言 `fetchUptime()` 得到 12345.0。

（提示：`systemUptime` 是 Double，Dart 侧用 `invokeMethod<double>`，注意 codec 里数字类型的映射——这正好是 L2 的引子。）
