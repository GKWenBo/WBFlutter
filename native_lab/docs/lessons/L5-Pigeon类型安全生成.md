# L5 Pigeon 类型安全生成

> 企业场景：前四课的桥全是**手写** `MethodChannel`/`EventChannel`——channel 名是字符串魔值、参数靠 `Map` 手拼手拆、类型对不上要到**运行期**才崩。团队一大，这套约定极易漂移：iOS 改了个字段名忘告诉 Android，编译一片绿、上线才炸。本课引入 **Pigeon**：写一份 Dart 定义文件当"契约"，一键生成三端类型安全的胶水代码，把"字符串魔值 + 手写编解码 + 运行期崩"换成"**定义即契约 + 生成代码 + 编译期红线**"。

本课把 **L1 的设备信息桥**用 Pigeon 重写成**独立的 L5 页**，**L1 手写版原样保留**——两页并排就是"手写 vs 生成"的活教材。

## 一、本课要掌握什么

**1. Pigeon 是"代码生成器"，不是新的通信机制。**

Pigeon **不取代** `MethodChannel`，它是**盖在 MethodChannel 上面的代码生成器**。底层仍是二进制 channel + codec，只是这些样板由它替你生成。所以前四课的心智（异步、`PlatformException`、主线程纪律）全都还在，只是不用手拼了。

你写的**唯一手写文件**是契约 `pigeons/device_info_api.dart`；跑一条命令后，它生成：

| 生成物 | 内容 | 对照前四课手写的什么 |
|---|---|---|
| `lib/lessons/l5/messages.g.dart` | 数据类 + `DeviceInfoHostApi()`（可直接调）+ 私有 channel + codec | L1 手写的 `MethodChannel(...)` + `invokeMethod` + 拆 Map |
| `ios/Runner/DeviceInfoMessages.g.swift` | 要你实现的协议 + `Setup.setUp` | L1 手写的 `FlutterMethodChannel` + `setMethodCallHandler` |
| `android/.../DeviceInfoMessages.g.kt` | 要你实现的 interface + `setUp` | L1 手写的 `MethodChannel(...).setMethodCallHandler` |

**2. ★ 手写 channel vs Pigeon（本课最核心的对比）。**

| 维度 | 手写 MethodChannel（L1–L4） | Pigeon（L5） |
|---|---|---|
| channel 名 | 字符串魔值 `'com.wenbo.native_lab/device_info'`，两端各写一遍，打错字运行期才崩 | 生成代码管理（`dev.flutter.pigeon.native_lab.*`），你根本不碰 |
| 方法名 | `invokeMethod('getDeviceInfo')`，字符串，打错字 → 运行期 `MissingPluginException`/`notImplemented` | `host.getDeviceInfo()` 是**真方法**，改名/打错字 → **编译报错** |
| 参数/返回 | `Map<String, Object?>` 手拼手拆，`map['model'] as String` 类型错运行期崩 | 生成的**强类型类** `DeviceInfoData`，字段点出来即有类型，少字段/类型错编译期报 |
| 编解码 | 你要懂 `StandardMessageCodec` 类型映射表（L2 那一堆坑：int/double、Integer/Long、Map cast） | codec 生成，类型映射它替你对齐 |
| 改契约 | 改一处，另外两端要手动同步，漏了不报错 | 改契约文件重跑生成，三端一起变；漏改的调用点**编译报错** |
| 测试桩 | 手写 `setMockMethodCallHandler` + 手拼返回值 | 直接 **fake 生成的 API**（继承 `DeviceInfoHostApi` 覆写方法）——见第四节 |

**3. 两个方向：HostApi（正向）+ FlutterApi（反向）。**

- `@HostApi()` = **Flutter → 原生**（对照 **L1**）。生成后 Dart 侧 `DeviceInfoHostApi()` 有真方法可调，原生侧实现协议/接口。
- `@FlutterApi()` = **原生 → Flutter**（反向）。生成后原生侧 `new` 一个 `DeviceEventFlutterApi` 实例，调 `onBatteryChanged(info)` 就把强类型对象推给 Dart。

本课用 FlutterApi 推**电量变化**，正好和 **L3 的 EventChannel** 做「同一件事、两种做法」对比：

| | L3 EventChannel | L5 Pigeon FlutterApi |
|---|---|---|
| 形态 | 一条 Stream，`onListen`/`onCancel` 生命周期 | 普通方法回调，原生主动调 |
| 事件类型 | 裸值 / `Map`，Dart 侧要手拆 | 生成的**强类型** `BatteryInfo` |
| 订阅管理 | `StreamBuilder` 自动 listen/cancel | 自己 `startBatteryUpdates`/`stopBatteryUpdates` + 把回调转 Stream |
| 取舍 | 天生就是"流"，页面订阅最省事 | 类型安全强；但"何时开始/停止推"要自己用方法控制 |

**4. `@async`：契约里标了，原生实现端就是 completion/callback。**

`@async PigeonDeviceInfo getDeviceInfo();` 生成后：iOS 是 `getDeviceInfo(completion:)`、Android 是 `getDeviceInfo(callback:)`——原生可异步完成再回值（对照 L1 handler 里的 `result(...)`）。Dart 侧无论是否 `@async` 都是 `Future`。

## 二、控件 / API 速查表

### 契约 & 生成（本课新东西）

| API | iOS 类比 | 用法 & 关键点 | 坑 |
|---|---|---|---|
| `pigeon`（dev_dependencies） | 代码生成工具（类比 SwiftGen/Sourcery） | `flutter pub add dev:pigeon` | 只在 dev 依赖，不进包体 |
| `@ConfigurePigeon(PigeonOptions(...))` | 生成器的配置 | 把 `dartOut`/`swiftOut`/`kotlinOut`/`kotlinOptions(package:)` 钉在契约文件里 | 路径写错会生成到奇怪地方 |
| `@HostApi()` | 协议定义（Flutter→原生） | 抽象方法即契约，生成调用端 + 原生 setUp | 类名**不能以 `Pigeon` 开头**（保留字，本课把类命名成 `DeviceInfoData`） |
| `@FlutterApi()` | 反向回调协议（原生→Flutter） | 生成原生调用端 + Dart 接收端 `setUp` | 接收端实例要留活（对照 L3 StreamHandler 强引用） |
| `@async` | 带 completion 的异步方法 | 原生实现端拿到 completion/callback | Dart 侧本来就是 Future，无差别 |
| `dart run pigeon --input pigeons/xxx.dart` | 跑一次代码生成 | 改了契约就重跑 | **生成物不要手改**，改了下次生成被覆盖 |

### Dart 侧

| API | iOS 类比 | 用法 & 关键点 | 坑 |
|---|---|---|---|
| `DeviceInfoHostApi()`（生成） | 调用一个协议实现 | `await host.getDeviceInfo()` 返回强类型 `DeviceInfoData` | 构造函数可传 `binaryMessenger`（用于依赖注入 / 测试） |
| `DeviceEventFlutterApi`（生成，abstract） | 反向协议 | 桥 `implements` 它，`setUp(this)` 把自己挂成接收端 | 只需实现 `onBatteryChanged` |
| `DeviceInfoData` / `BatteryInfo`（生成） | 生成的 model struct | 字段强类型，直接 `info.model` | 字段非空则少传编译报错 |

### 原生侧

| API | 说明 | 坑 |
|---|---|---|
| iOS `DeviceInfoHostApiSetup.setUp(binaryMessenger:api:)` | 挂载实现 | api 实例要强引用（本课用 AppDelegate 存储属性），否则被释放 |
| iOS `DeviceEventFlutterApi(binaryMessenger:)` | 反向调用端 | `onBatteryChanged(info:) { _ in }` 推事件 |
| Android `DeviceInfoHostApi.setUp(messenger, impl)` | 挂载实现 | `@async` → `getDeviceInfo(callback:)` |
| Android `DeviceEventFlutterApi(messenger)` | 反向调用端 | 广播回调 `runOnUiThread` 再推（对照 L3） |

## 三、代码地图

**契约（唯一手写源）**
- `pigeons/device_info_api.dart` — `@ConfigurePigeon` 配置 + `DeviceInfoData`/`BatteryInfo` 数据类 + `@HostApi DeviceInfoHostApi` + `@FlutterApi DeviceEventFlutterApi`。

**生成物（不手改）**
- `lib/lessons/l5/messages.g.dart`、`ios/Runner/DeviceInfoMessages.g.swift`、`android/app/src/main/kotlin/com/wenbo/native_lab/DeviceInfoMessages.g.kt`。

**Dart 侧（手写）**
- `lib/lessons/l5/device_info_pigeon_bridge.dart` — 薄封装：持生成的 `DeviceInfoHostApi()`（构造可注入，测试传 fake）；`implements DeviceEventFlutterApi` 把反向电量回调转成 `batteryStream`。
- `lib/lessons/l5/l5_pigeon_page.dart` — `StatefulWidget`：`initState` 建 bridge，"读取设备信息"按钮调正向、开关调 `start/stopBatteryUpdates` + `StreamBuilder` 显示反向电量，`dispose` 清理。
- `lib/lessons/lesson_registry.dart` — L5 `inProgress` + `pageBuilder`。

**iOS 侧（手写实现）**
- `ios/Runner/AppDelegate.swift` — 第五处并列注册：`DeviceInfoPigeonHost`（实现生成协议 + 持 `DeviceEventFlutterApi`，`UIDevice` 电量通知回推），AppDelegate 用存储属性强引用它。

**Android 侧（手写实现）**
- `MainActivity.kt` — `DeviceInfoPigeonHost`（inner class 实现生成 interface + 持 `DeviceEventFlutterApi`，`BroadcastReceiver(ACTION_BATTERY_CHANGED)` 回推）。

## 四、测试怎么写（本课的新姿势）

pigeon 27 **弃用了"生成 mock host"**（`@HostApi(dartHostTestHandler:)`），源码里的弃用说明原话是 *"Mock/fake the generated Dart API instead."* 所以本课测试改走**依赖注入 + fake 生成的 API**：

```dart
// 继承生成的 DeviceInfoHostApi、覆写方法当假原生，通过构造函数注入 bridge。
class _FakeHost extends DeviceInfoHostApi {
  @override
  Future<DeviceInfoData> getDeviceInfo() async =>
      DeviceInfoData(model: 'iPhone', systemName: 'iOS', systemVersion: '18.0',
                     isPhysicalDevice: false, batteryLevel: 80);
  // ...
}

final bridge = DeviceInfoPigeonBridge(hostApi: _FakeHost());
expect((await bridge.getDeviceInfo()).model, 'iPhone'); // 强类型，编译期就对
```

- **正向**：注入 fake host，验证 bridge 转发 + 返回强类型（对照 L1 的 `setMockMethodCallHandler` + 手拼 Map，这里桩更贴近真调用）。
- **反向**：直接 `bridge.onBatteryChanged(BatteryInfo(...))`，验证 `batteryStream` 吐出（对照 L3）。
- **页面**：页面自己 `new bridge()` 没法注入 fake，就用 `setMockDecodedMessageHandler` 在 **Pigeon 私有 channel**（`BasicMessageChannel`，回复是 `[返回值]` 的 List）上顶替原生——顺带印证"Pigeon 底层仍是 channel"。

共 4 测（3 桥 + 1 页面），全量 `flutter test` 35 过、`flutter analyze` 0。

## 五、双端对照（Swift vs Kotlin）

| 维度 | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| 挂载 | `DeviceInfoHostApiSetup.setUp(binaryMessenger:api:)` + 实现 `protocol` | `DeviceInfoHostApi.setUp(messenger, impl)` + 实现 `interface` |
| `@async` 生成签名 | `getDeviceInfo(completion: (Result<T, Error>) -> Void)` | `getDeviceInfo(callback: (Result<T>) -> Unit)` |
| 反向调用端 | `DeviceEventFlutterApi(binaryMessenger:)` 类实例 | `DeviceEventFlutterApi(messenger)` 同名 class |
| 电量数据源 | `UIDevice.isBatteryMonitoringEnabled` + `batteryLevelDidChangeNotification`/`batteryStateDidChangeNotification` | `BatteryManager` + `BroadcastReceiver(ACTION_BATTERY_CHANGED)`（粘性广播，注册即回一次） |
| 回主线程 | 通知回调本在主线程，直接推 | 广播回调 `runOnUiThread` 再推（对照 L3） |
| 实例保命 | AppDelegate 存储属性强引用 host | inner class（外层 Activity 持有） |

> 本课 iOS 主讲、模拟器验证；Android 为完整对照实现（本机不强制跑安卓）。

## 六、自测清单

1. Pigeon 相比手写 `MethodChannel` 到底省了什么？它**编译期**能抓住哪些手写做不到的错？
2. `@HostApi` 和 `@FlutterApi` 分别对应前面哪一课的方向？各自生成什么（Dart 侧 / 原生侧）？
3. pigeon 27 里我们怎么给桥写测试？替代了 L1 里手写的什么？
4. Pigeon 反向（FlutterApi）和 L3 EventChannel 都能"原生推 Flutter"，差别与取舍是什么？
5. 改了契约的字段名，不重跑生成会怎样？为什么说这正是 Pigeon 的价值？

> 自测答案见 [自测答案/L5-自测答案.md](自测答案/L5-自测答案.md)。

## 七、课后练习

给契约加一个 HostApi 方法 `getBatteryInfo() -> BatteryInfo`（一次性取当前电量，不订阅）：

1. 在 `pigeons/device_info_api.dart` 的 `DeviceInfoHostApi` 里加这个方法；
2. `dart run pigeon --input pigeons/device_info_api.dart` 重跑生成；
3. **三端补实现**（不补的话 iOS/Android 编译直接报错——体会"契约驱动"）；
4. 页面加个"读一次电量"按钮；
5. 补一条测试：`_FakeHost` 覆写 `getBatteryInfo`，断言 bridge 返回的 `BatteryInfo` 正确。

练的就是 **改契约 → 生成 → 三端同步**的完整回路，以及"漏改一端编译就拦住你"的安全感。
