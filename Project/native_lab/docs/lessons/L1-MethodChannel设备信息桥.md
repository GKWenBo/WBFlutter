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

**5. 三条容易被忽略的工程纪律（面试常挖，先记住）。**

- **一条 channel 名只能有一个 handler。** 两端都是"后注册覆盖先注册"——同名 channel 在 `setMethodCallHandler` 第二次注册时，前一个 handler 会被**静默替换**，不报错。所以 channel 名一定要带反域名前缀（本课是 `com.wenbo.native_lab/device_info`），插件更要避开业务命名（L7 会专门讲）。
- **channel 默认只能在 root isolate 上用。** 你在 `compute()` / 自建 isolate 里 `invokeMethod` 会直接报错。需要在后台 isolate 用 channel，得先在主 isolate 拿 `RootIsolateToken.instance!` 传过去，后台侧 `BackgroundIsolateBinaryMessenger.ensureInitialized(token)` 之后才能用。
- **没有超时机制**（见上文）。企业里通常在桥接层统一包一层 `.timeout(const Duration(seconds: 3))`，并把 `TimeoutException` 也转成自己的领域错误——**别让 UI 去 catch 三种不同的异常**。

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

## 七、面试高频题（附答案）

> 面试语境：**这是整门课被问得最多的一课**。只要简历上写了"混合开发"，`MethodChannel` 原理几乎必问，而且会顺着"链路 → 线程 → 异常 → 测试"一路追问下去。

**Q1. 讲一下 MethodChannel 的实现原理，一次 `invokeMethod` 完整走了哪些环节？**

分五步答（**编码 → 投递 → 分发 → 回执 → 解码**）：

1. Dart 侧 `MethodChannel` 用 **`StandardMethodCodec`** 把「方法名 + 参数」编码成一段 `ByteData`；
2. 交给 **`BinaryMessenger`**（引擎提供的二进制信使）按 **channel 名**投递，消息从 **UI 线程**跨到 **Platform 线程**；
3. 引擎按 channel 名找到原生侧注册的 handler，在 **Platform 线程（iOS 主线程）**调用它；
4. 原生调 `result(...)`，返回值再被 codec 编码成二进制回传；
5. Dart 侧解码，完成 `invokeMethod` 返回的那个 `Future`。

关键点一句话：**channel 名是路由键，codec 是序列化协议，BinaryMessenger 是唯一的传输层**——`MethodChannel`/`EventChannel`/`BasicMessageChannel` 三者只是 codec 和调用语义不同，传输层是同一个。

**Q2. `MissingPluginException` 怎么排查？你的排查顺序是什么？**

按"从近到远"六步查：

1. **channel 名两端是否逐字符一致**（最常见，建议抽成共享常量而不是各写一遍字符串）；
2. **方法名是否一致**，原生 `default` 分支是不是回了 `FlutterMethodNotImplemented`；
3. **原生侧到底注册了没有**——插件忘了 `pub get`、自写的桥忘了在 `AppDelegate`/`configureFlutterEngine` 里注册；
4. **注册挂在哪台引擎上**（重点）：channel 是**绑引擎**的，add-to-app 里新建的引擎没挂通道就必然是这个异常（L8 实测踩过）；
5. **当前平台有没有实现**：只写了 iOS，跑 Android/Web 自然没有；
6. 热重启 / 引擎重建后原生侧是否重新注册。

**Q3. 原生 handler 跑在哪条线程？里面要做耗时操作（读数据库、网络）怎么办？**

跑在 **Platform 线程 = iOS 主线程**。直接在里面做耗时活会**卡住整个 App 的主线程**（原生 UI 和 Flutter 的平台任务一起卡）。

正确做法：handler 里立刻把活派到子线程/子队列，做完**再回到主线程**调 `result`：

```swift
DispatchQueue.global(qos: .userInitiated).async {
    let value = expensiveWork()
    DispatchQueue.main.async { result(value) }   // 回主线程再回执
}
```

Kotlin 侧同理（协程/线程池做完 `runOnUiThread { result.success(...) }`）。这条线程纪律 L3（sink 回调）、L4（权限回调里 present）会反复出现。

**Q4. `PlatformException` 和 `MissingPluginException` 有什么区别？分别什么时候出现？**

| | 触发方 | 含义 | 处理 |
|---|---|---|---|
| `PlatformException` | 原生主动 `result(FlutterError(code:...))` | **业务失败**（没权限、没电池、参数非法） | 按 `e.code` 分支降级，给用户可操作的提示 |
| `MissingPluginException` | 引擎找不到 handler，或原生回了 `FlutterMethodNotImplemented` | **接线错误**（工程问题，不是业务问题） | 不该给用户看，应在开发期就被测试/日志抓住 |

面试加分点：**两者要分开 catch**。前者是可预期的业务分支，后者说明"两端契约漂移了"，属于 bug，应该上报监控而不是静默兜底。

**Q5. channel 调用是同步还是异步？能不能做成同步？消息有顺序保证吗？**

**只有异步**，因为 Dart 在 UI 线程、原生在 Platform 线程，跨线程投递天然拿不到同步返回值。真要同步调原生只能绕开 channel 走 **`dart:ffi`**（直接同线程调 C ABI 函数）。

顺序：**同一条 channel 上的消息按发送顺序投递**，原生 handler 也按顺序被调用；但如果原生 handler 内部异步处理（如 Q3 那样派到子线程），**回执顺序就不保证了**——需要有序就自己在参数里带 seq/requestId。

**Q6. `FlutterResult` 有什么使用约束？违反了会怎样？**

- **必须调，且只能调一次。**
- 不调：Dart 侧那个 `Future` **永久挂起**——UI 上表现为菊花转到天荒地老，且没有任何异常可 catch（channel 本身没有超时）。
- 调多次：引擎会判定为重复回复（日志报错/断言），Dart 侧只认第一次。
- L4 的"延迟结果"场景（present 出去等用户操作）最容易踩这两条，所以那一课要专门做**在飞行守卫 + 回完置 nil**。

**Q7. channel 的性能开销有多大？能不能每帧调一次？**

单次调用是一次二进制序列化 + 一次跨线程投递，量级在**微秒到几十微秒**，偶发调用完全无感。但它**不适合高频**（每帧、每个触摸事件）：一是累积开销，二是异步导致的**帧不同步**（数据回来时已经晚了一帧）。

高频场景的替代路径：
- 数据源在原生但变化频繁 → 让原生**节流/聚合**后再推（L3 EventChannel）；
- 需要每帧同步的纯计算 → 用 **FFI**；
- 需要每帧的**图像**（相机/视频）→ 走 **Texture / PlatformView**，别把像素往 channel 上搬。

**Q8. 桥接层代码怎么做单元测试？CI 上没有模拟器也能测吗？**

能。用 `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, handler)` 把"假原生"挂上去，就能在纯 Dart 环境覆盖：① 是否发出了正确的方法名和参数；② 返回的 Map 是否被正确收成强类型模型；③ 原生回 `FlutterError` 时是否转成了预期的领域异常；④ `MissingPluginException` 的兜底分支。

**测不到的**是原生实现本身（那要么写 XCTest/JUnit，要么模拟器实跑）。回答时点出这条边界，比只说"我用 mock"要显得清楚得多。
