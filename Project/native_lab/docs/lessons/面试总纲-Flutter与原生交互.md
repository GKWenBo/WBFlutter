# 面试总纲：Flutter 与原生交互

> 这份文档是 NativeLab 十课的**面试向索引**：把每课末尾的「面试高频题」抽成一张总表，再补上跨课的选型题、手撕题、场景题和踩坑故事。
> 每课的详细答案在各自文档的「面试高频题（附答案）」一节，这里只给**一句话答案 + 去哪看**。
>
> 适用人群：有原生（iOS/Android）背景、面 Flutter / 混合开发岗的工程师。

---

## 一、怎么用这份文档

| 场景 | 怎么刷 | 时间 |
|---|---|---|
| **面试前一晚** | 只看第二节「五张必背卡」+ 第七节「踩坑红榜」 | 30 分钟 |
| **约到面试，还有几天** | 第三节 30 题过一遍，答不上来的点进对应课细看 | 3~4 小时 |
| **系统准备** | 十课正文 + 自测清单 + 课后练习全做，再回来刷第四/五/六节 | 按课程节奏 |

**答题总原则（比背答案更重要）：**

1. **先给结论，再给原理，最后给代价。** 面试官问"用哪个"，你答"我选 X，因为 Y，代价是 Z，如果 W 变了我会改选 V"——这是高级工程师的答法。
2. **能举自己踩过的坑就举。** 第七节给了 8 个本课程真实踩过的坑，每个都是现成的故事素材。
3. **主动划边界。** "这个能测、那个测不了，各归各管"比"我都会"可信。

---

## 二、五张必背卡

### 卡 1 · 类型映射表（L2）

| Dart | Swift (iOS) | Kotlin (Android) |
|---|---|---|
| `null` | `NSNull` / `nil` | `null` |
| `bool` | `NSNumber` → `Bool` | `Boolean` |
| `int`（≤32 位） | `NSNumber` → `Int` | `Integer` |
| `int`（>32 位） | `NSNumber` → `Int` | **`Long`** ⚠️ |
| `double` | `NSNumber` → `Double` | `Double` |
| `String` | `String` | `String` |
| `Uint8List` | `FlutterStandardTypedData` | `ByteArray` |
| `List` / `Map` | `NSArray` / `NSDictionary` | `List` / `Map`（键值都是 `Any?`） |

**记忆钩子**：iOS 侧数字**全是 `NSNumber`**（无坑）；Android 侧**按大小分裂 `Integer`/`Long`**（坑都在这，一律 `(x as Number).toLong()`）。回到 Dart 时容器是 `Map<Object?,Object?>`，**必须 cast 收窄**。

### 卡 2 · 三种 channel + 四种 codec（L2）

| Channel | 语义 | 用途 |
|---|---|---|
| `MethodChannel` | 一问一答 RPC（带方法名） | 调一次原生能力 |
| `EventChannel` | 订阅-推送流 | 持续监听会变的东西 |
| `BasicMessageChannel` | 无方法名的双向裸消息 | 高频小消息 / 自定义协议；**Pigeon 底层用的就是它** |

四种 codec：`StandardMessageCodec`（默认，二进制）、`JSONMessageCodec`、`StringCodec`、`BinaryCodec`（完全不编解码）。

**一句话**：三者共用同一个 `BinaryMessenger`，**MethodChannel = 带方法名的 BasicMessageChannel，EventChannel = 约定了 `listen`/`cancel` 两个方法名的 MethodChannel。**

### 卡 3 · 线程模型 + 三条线程纪律（L0/L1/L3/L4）

四个 task runner：**Platform（= iOS 主线程）/ UI（跑全部 Dart 代码）/ Raster（栅格化）/ IO（图片解码）**。

三条纪律：

1. **原生 handler 在主线程** → 耗时活派到子线程，做完**回主线程**调 `result`（L1）；
2. **系统回调常在后台线程** → 往 `EventSink` 推事件前必须切回主线程（L3）；
3. **权限回调在任意线程** → 里面要 `present` 必须切主线程（L4）。

**Dart 不在主线程 ⇒ 通信必然异步 ⇒ `invokeMethod` 返回 `Future`。要同步只能走 FFI。**

### 卡 4 · 四种"混原生"的形态（L4/L6/L8）

| 形态 | 谁是宿主 | 长什么样 | 场景 |
|---|---|---|---|
| **数据过桥**（L1–L3、L5） | Flutter | 只传数据/流 | 设备信息、埋点、网络状态 |
| **页面级混合**（L4） | Flutter | 原生页**盖住整屏**，拿结果就退 | 扫码、拍照、原生支付/认证 |
| **视图级混合**（L6） | Flutter | 原生 view 是布局里的**一个 widget**，同屏共存 | 地图、WebView、相机预览、广告 |
| **add-to-app**（L8/L9） | **原生 App** | Flutter 页寄居在原生工程里 | 老 App 用 Flutter 写新模块 |

**口诀：盖住整屏 → L4；同屏共存 → L6；角色对调 → L8。**

### 卡 5 · 引擎与通道的四条铁律（L8/L9）

1. **通道绑引擎，不是全局的。** 每台引擎都要各自挂通道、各自注册插件——漏了就是 `MissingPluginException` 或"点了没反应"。
2. **引擎常驻 = 状态常驻。** 关页面只是移走窗口，Dart 的 widget 树和内存还在；要重置得**显式清**。
3. **`setInitialRoute` 只对没 `run()` 的引擎有效。** 热引擎换页要通道驱动 `Navigator`（配全局 `navigatorKey`）。
4. **谁 present 的，谁负责 dismiss。** 模块不能自己 pop 掉被原生 present 的根页。

---

## 三、30 题速查清单

> ★ = 必答（答不上来基本挂）｜★★ = 进阶（区分做过没做过）｜★★★ = 加分（有真实项目经验才答得出）

### A. 基础与原理（L0–L2）

| # | 题目 | 一句话答案 | 详解 |
|---|---|---|---|
| 1 | ★ Debug/Release 有什么区别？Dart 代码在包里是什么形式？ | Debug 是 JIT（所以有热重载），Release 是 AOT 机器码；iOS 落成 `App.framework`+`Flutter.framework`，Android 是 `libapp.so`+`libflutter.so` | [L0](L0-工程创建与原生工程解剖.md) |
| 2 | ★ Flutter 有几条线程？Dart 跑在哪？ | 四个 task runner；Dart 在 UI 线程，原生在 Platform 线程（= iOS 主线程） | [L0](L0-工程创建与原生工程解剖.md) |
| 3 | ★ FlutterEngine 和 FlutterViewController 什么关系？ | 引擎是内核（能脱离 UI 存活），VC 只是展示窗口 | [L0](L0-工程创建与原生工程解剖.md) |
| 4 | ★ Flutter 的 UI 是原生控件吗？和 RN 的本质区别？ | 不是，全自绘（Skia/Impeller）；RN 是翻译成真实原生控件 | [L0](L0-工程创建与原生工程解剖.md) |
| 5 | ★★ 热重载原理？哪些改动救不了？ | 增量 kernel 推给 VM 换函数体、保留 state；救不了结构性改动、已执行的一次性逻辑、全局变量初值、**原生代码** | [L0](L0-工程创建与原生工程解剖.md) |
| 6 | ★ 讲讲 MethodChannel 原理，一次调用走哪些环节？ | 编码（codec）→ 投递（BinaryMessenger 跨线程）→ 原生 handler（Platform 线程）→ result 编码回传 → Future 完成 | [L1](L1-MethodChannel设备信息桥.md) |
| 7 | ★ `MissingPluginException` 怎么排查？ | 名字 → 方法名 → 注册没有 → **挂在哪台引擎** → 当前平台有没有实现 → 热重启后是否重注册 | [L1](L1-MethodChannel设备信息桥.md) |
| 8 | ★ 原生 handler 在哪条线程？耗时活怎么办？ | 主线程；派到子线程做，**回主线程**调 result | [L1](L1-MethodChannel设备信息桥.md) |
| 9 | ★ `PlatformException` vs `MissingPluginException`？ | 前者是**业务失败**（该降级），后者是**接线错误**（是 bug，该上报） | [L1](L1-MethodChannel设备信息桥.md) |
| 10 | ★★ channel 能同步调用吗？有超时吗？消息有序吗？ | 不能同步（要同步走 FFI）；**没有超时**（自己包 `.timeout`）；同一 channel 按序投递，但原生异步处理后回执顺序不保证 | [L1](L1-MethodChannel设备信息桥.md) |
| 11 | ★★ `FlutterResult` 有什么约束？ | **必须调、且只能调一次**；不调 → Future 永久挂起；调两次 → 引擎报重复回复 | [L1](L1-MethodChannel设备信息桥.md) |
| 12 | ★★★ 后台 isolate 里能用 channel 吗？ | 默认不能；要传 `RootIsolateToken` 过去，用 `BackgroundIsolateBinaryMessenger.ensureInitialized` | [L1](L1-MethodChannel设备信息桥.md) |
| 13 | ★ Dart 的 `int` 到 Android 是什么？为什么 `as Int` 会崩？ | 小值 `Integer`、大值 `Long`（时间戳必崩）；一律 `(x as Number).toLong()` | [L2](L2-数据编解码与复杂参数.md) |
| 14 | ★★ 自定义对象怎么过桥？ | 拍平成 Map / 扩展 codec（自定义 type id ≥128）/ **用 Pigeon（团队正解）** | [L2](L2-数据编解码与复杂参数.md) |
| 15 | ★★ 传图片/大文件怎么传？ | 小字节流用 `Uint8List`（零拷贝，别 base64）；大文件传**路径**；每帧像素走**纹理** | [L2](L2-数据编解码与复杂参数.md) |
| 16 | ★★ 三种 channel 分别是什么？`BasicMessageChannel` 何时用？ | 见卡 2；无方法名的双向消息，适合高频小消息/自定义协议 | [L2](L2-数据编解码与复杂参数.md) |

### B. 流、页面、视图（L3–L6）

| # | 题目 | 一句话答案 | 详解 |
|---|---|---|---|
| 17 | ★ EventChannel 和 MethodChannel 怎么选？ | 做一次拿结果 → Method；盯着会变的东西 → Event。别用轮询代替流 | [L3](L3-EventChannel网络状态推流.md) |
| 18 | ★★ `onListen`/`onCancel` 何时触发？忘了 `onCancel` 会怎样？ | 首个订阅 / 最后一个取消；忘了拆监听 = **泄漏 + 耗电** | [L3](L3-EventChannel网络状态推流.md) |
| 19 | ★★★ EventChannel 有背压吗？高频事件怎么办？ | **没有**；必须在**原生侧**降采样/节流/聚合，Dart 侧节流已经晚了 | [L3](L3-EventChannel网络状态推流.md) |
| 20 | ★★★ `receiveBroadcastStream()` 能写在 `build()` 里吗？ | 不能，每次调用是新流 → 原生 `onCancel`/`onListen` 反复抖动 | [L3](L3-EventChannel网络状态推流.md) |
| 21 | ★ 怎么调起原生扫码页并拿回结果？ | 暂存 `FlutterResult`，present，dismiss 回调里回值并置空；配在飞行守卫 | [L4](L4-页面级混合与权限.md) |
| 22 | ★★ 运行时权限三态怎么处理？被拒之后呢？ | authorized 直接干；notDetermined 才 request；denied **不再 request**，引导去设置。`Info.plist` 缺声明**直接崩** | [L4](L4-页面级混合与权限.md) |
| 23 | ★ Pigeon 解决什么问题？ | 把 channel 名/方法名/字段类型的**运行期错误提前到编译期**；改契约后漏改的地方直接编译不过 | [L5](L5-Pigeon类型安全生成.md) |
| 24 | ★★ Pigeon 是新通信机制吗？限制是什么？ | 不是，是生成器（底层 `BasicMessageChannel`+扩展 codec）；不支持继承/泛型，生成物不可手改，多一个生成步骤 | [L5](L5-Pigeon类型安全生成.md) |
| 25 | ★★ Pigeon / 手写 channel / FFI 怎么选？ | 系统能力→channel；团队协作+接口稳定→Pigeon；调 C/C++ 或要同步→FFI | [L5](L5-Pigeon类型安全生成.md) |
| 26 | ★ PlatformView 为什么贵？ | 因为它**把 Flutter 原本一整块的合成拆开了**（纹理拷贝/多层合成/线程配合），不是"多画一个 view" | [L6](L6-PlatformView视图级混合.md) |
| 27 | ★★★ 原生视图和 Flutter 手势冲突怎么解？ | Flutter 竞技场默认优先；用 `gestureRecognizers` 传 `EagerGestureRecognizer` 把手势抢给原生 | [L6](L6-PlatformView视图级混合.md) |
| 28 | ★★ Android 的 VD / HC / TLHC 是什么？ | 虚拟显示 → 混合合成 → 纹理层混合合成（3.0 起默认）；iOS 只有图层交错一条路 | [L6](L6-PlatformView视图级混合.md) |

### C. 插件与 add-to-app（L7–L9）

| # | 题目 | 一句话答案 | 详解 |
|---|---|---|---|
| 29 | ★ 插件的自动注册怎么实现的？ | pubspec 声明 → `pub get` 生成 `GeneratedPluginRegistrant` → 引擎启动时挨个调 `register`；**自己 new 的引擎要手动调** | [L7](L7-插件开发.md) |
| 30 | ★★ 三层结构（门面/接口/实现）中间那层能去掉吗？ | 能跑，但丢了换实现的能力、测试注入点、拆联邦的可能 | [L7](L7-插件开发.md) |
| 31 | ★★★ 什么是联邦插件？什么时候值得拆？ | 门面包 + 接口包 + 各平台实现包（`implements:`/`default_package:`/endorsed）；平台多、多团队维护、要允许替换实现时才拆 | [L7](L7-插件开发.md) |
| 32 | ★★ `PlatformInterface` 的 token 校验干嘛的？ | 强制 `extends` 而非 `implements`，让接口能安全演进；测试用 `MockPlatformInterfaceMixin` 合法绕过 | [L7](L7-插件开发.md) |
| 33 | ★★★ Android 插件要用 Activity 怎么办？ | 实现 `ActivityAware` 四个回调——**Activity 会因配置变更重建，引擎不会** | [L7](L7-插件开发.md) |
| 34 | ★ add-to-app 怎么接？`install_all_flutter_pods` 做了什么？ | 把引擎+Dart 产物+所有插件变成 Pod 依赖并配好构建脚本；之后必须用 `.xcworkspace` | [L8](L8-add-to-app原生工程接入Flutter.md) |
| 35 | ★★★ 原生同事不装 Flutter SDK 怎么办？ | 走**产物集成**：`flutter build ios-framework` / `build aar` 发私有仓库；代价是 Dart 改动要重新发版 | [L8](L8-add-to-app原生工程接入Flutter.md) |
| 36 | ★★ 冷启动白屏怎么来的？怎么优化？ | 当场建引擎+跑 main+建树；优化：**预热** > 占位图 > 首屏轻量化 > 按业务域预热 | [L8](L8-add-to-app原生工程接入Flutter.md) |
| 37 | ★★ add-to-app 怎么调试热重载？ | Xcode 跑宿主 → module 目录 `flutter attach` | [L8](L8-add-to-app原生工程接入Flutter.md) |
| 38 | ★ 引擎预热的收益和代价？何时不该预热？ | 秒开 vs **内存常驻 + 拖慢启动**；极少进的边角功能别预热 | [L9](L9-add-to-app引擎管理与通信.md) |
| 39 | ★★★ 热引擎上 `setInitialRoute` 为什么无效？ | `initialRoute` 只在建 widget 树那一刻读；热引擎要用通道驱动 `Navigator`（全局 `navigatorKey`） | [L9](L9-add-to-app引擎管理与通信.md) |
| 40 | ★★★ 混合栈怎么选？要不要上 flutter_boost？ | 少数独立入口 → 单引擎；大量交错 → 多引擎/`FlutterEngineGroup`/框架；boost 的代价是重依赖 + 升级要等适配 | [L9](L9-add-to-app引擎管理与通信.md) |

---

## 四、手撕代码题（现场白板）

### 题 1 · 手写一条 MethodChannel（双端）

**要求**：Flutter 调原生取电量，处理失败。考察点：channel 名常量化、错误码约定、`result` 只调一次、强类型收口。

```dart
// Dart 侧：桥接层收口，别让 Map 流进业务
class BatteryBridge {
  static const _channel = MethodChannel('com.example.app/battery');

  static Future<int> level() async {
    try {
      final v = await _channel
          .invokeMethod<int>('getBatteryLevel')
          .timeout(const Duration(seconds: 3));   // channel 自己没有超时
      return v ?? -1;
    } on PlatformException catch (e) {
      if (e.code == 'UNAVAILABLE') return -1;     // 业务失败：降级
      rethrow;
    } on MissingPluginException {
      rethrow;                                    // 接线错误：该上报，不该静默
    }
  }
}
```

```swift
// Swift 侧：注意 default 分支、错误码、只调一次 result
channel.setMethodCallHandler { call, result in
    switch call.method {
    case "getBatteryLevel":
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        if level < 0 {
            result(FlutterError(code: "UNAVAILABLE", message: "模拟器无电池", details: nil))
        } else {
            result(Int(level * 100))
        }
    default:
        result(FlutterMethodNotImplemented)   // 别用 result(nil) 冒充
    }
}
```

**面试官会追问**：这里要是做磁盘 IO 怎么写？（→ 派到子线程，回主线程 `result`）channel 名重复了会怎样？（→ 后注册覆盖先注册，静默）

### 题 2 · 手写 EventChannel 的原生端

**要求**：推网络状态。考察点：`onListen` 建、`onCancel` 拆、**监听源不可复用**、切主线程。

```swift
final class NetworkStreamHandler: NSObject, FlutterStreamHandler {
    private var monitor: NWPathMonitor?

    func onListen(withArguments _: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        let m = NWPathMonitor()                       // ★ 每次订阅新建（cancel 后不可复用）
        m.pathUpdateHandler = { path in
            let type = path.status == .satisfied ? "wifi" : "none"
            DispatchQueue.main.async { events(type) } // ★ 回调在后台队列，必须切主线程
        }
        m.start(queue: DispatchQueue(label: "net.monitor"))
        monitor = m
        return nil
    }

    func onCancel(withArguments _: Any?) -> FlutterError? {
        monitor?.cancel()
        monitor = nil                                 // ★ 置空，防止下次复用死对象
        return nil
    }
}
```

**面试官会追问**：忘了 `onCancel` 会怎样？（泄漏+耗电）事件每秒来 100 次怎么办？（原生侧节流）handler 谁持有？（要强引用，否则被回收、监听失效）

### 题 3 · 写一份 Pigeon 契约

**要求**：设备信息 + 电量推送。考察点：知道两个方向、`@async` 的含义、类名限制。

```dart
// pigeons/device_api.dart —— 唯一手写文件
@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/messages.g.dart',
  swiftOut: 'ios/Runner/Messages.g.swift',
  kotlinOut: 'android/app/src/main/kotlin/com/example/Messages.g.kt',
))
class DeviceInfoData {          // ★ 类名不能以 Pigeon 开头（保留字）
  DeviceInfoData({required this.model, required this.batteryLevel});
  final String model;
  final int batteryLevel;
}

@HostApi()                       // Flutter → 原生
abstract class DeviceHostApi {
  @async DeviceInfoData getDeviceInfo();   // 原生端拿到 completion/callback
}

@FlutterApi()                    // 原生 → Flutter
abstract class DeviceEventApi {
  void onBatteryChanged(int level);
}
```

**面试官会追问**：改了字段名不重跑生成会怎样？（什么都不会发生，因为契约不参与编译——所以要把生成挂进 CI 校验）生成物要提交吗？（要，否则别人拉下来编不过）

---

## 五、场景设计题（大厂常考）

### 场景 1 · "老 App 要接 Flutter，你怎么设计？"

→ 直接用 [L9 第 Q9 题](L9-add-to-app引擎管理与通信.md)的七步框架：接入方式 → 引擎策略 → 通信层 → 路由 → 状态管理 → 工程化 → 可观测性。

### 场景 2 · "Flutter 页打开慢/白屏，你怎么排查优化？"

分三段排查，**先定位是哪一段慢**：

| 段 | 症状 | 手段 |
|---|---|---|
| 引擎启动 | add-to-app 里点开就白 | 预热引擎（L9）；占位图过渡 |
| 首帧构建 | 引擎已热但仍卡一下 | 首帧别做重活（网络/大列表/大图解码）；`RepaintBoundary`、避免同步 IO |
| 数据加载 | 首帧出来了但内容空 | 骨架屏 + 分段渲染；数据预取（原生侧在预热时就拿好，Flutter 起来直接要） |

工具：DevTools 的 Timeline / Performance overlay、Xcode Instruments。

### 场景 3 · "原生的登录态怎么给 Flutter 用？"

要点：① **收口成一个宿主通道**（别到处开桥）；② 用 Pigeon 定契约保证类型安全；③ **token 不做 Dart 侧长期缓存**——引擎常驻意味着退出登录后旧 token 可能还在（安全问题），要么每次现取，要么原生主动推变更 + Flutter 侧监听；④ 通道要在**每台引擎**上都挂（含冷启动路径）。

### 场景 4 · "要在 Flutter 里放一个高德地图，你怎么做？"

① **优先用官方 Flutter 插件**（已处理合成模式/手势/生命周期/双端对齐）；② 没有插件才自己写 PlatformView：viewType 常量化、每实例一条通道、`creationParams` 传初始状态、`dispose` 里释放；③ 注意手势冲突（`EagerGestureRecognizer`）和**不要放进长列表**；④ 测试分层：Dart 逻辑单测 + 原生渲染实跑。

---

## 六、"你踩过什么坑" —— 8 个现成的故事素材

> 讲的时候按「现象 → 排查 → 根因 → 修法 → 引申」五段说。
> 其中 **1、3、5、6、7、8 是本仓库真实踩到并修复过的**（各课文档里都有记录，讲起来有细节）；2、4 是文档里记录的典型坑，没亲历就别说成自己踩的。

| # | 现象 | 根因 | 出处 |
|---|---|---|---|
| 1 | 页面第二次进入一直转圈 | `NWPathMonitor` cancel 后不可复用，第二次订阅用了个死对象 | [L3](L3-EventChannel网络状态推流.md) |
| 2 | 大 id 正常、时间戳一来就崩 | Android 侧大整数是 `Long`，`as Int` 抛 `ClassCastException` | [L2](L2-数据编解码与复杂参数.md) |
| 3 | Dart 侧 `TypeError`，锅在原生 | 原生约定回 `int` 却回了 `double`，codec 不做隐式转换 | [L2](L2-数据编解码与复杂参数.md) |
| 4 | 一调相机就崩 | `Info.plist` 缺 `NSCameraUsageDescription` | [L4](L4-页面级混合与权限.md) |
| 5 | Flutter 页"关闭"按钮点了没反应，用户被困住 | **通道绑引擎**，冷启动新建的引擎没挂通道 | [L8](L8-add-to-app原生工程接入Flutter.md) |
| 6 | 点"打开详情页"，打开的还是首页 | 热引擎上 `setInitialRoute` 无效（widget 树早建好了） | [L9](L9-add-to-app引擎管理与通信.md) |
| 7 | 关掉页面再进，模块还记得上一个用户的 token | 引擎常驻 = 状态常驻，必须显式 reset | [L9](L9-add-to-app引擎管理与通信.md) |
| 8 | `pod install` 报 ASCII-8BIT / 构建报 Sandbox deny | CocoaPods 需要 UTF-8 locale；Xcode 15+ 的 `ENABLE_USER_SCRIPT_SANDBOXING` 要改 NO | [L8](L8-add-to-app原生工程接入Flutter.md) |

---

## 七、怎么把这门课讲成"项目经历"

别说"我学了个教学项目"。按下面这样组织（三段话，40 秒）：

> **背景**：我有 N 年 iOS 经验，团队要在既有原生 App 里引入 Flutter 写新模块，我负责打通原生交互这一层。
>
> **做了什么**：搭了一个原生能力实验室工程，把混合开发的完整链路走通并沉淀成规范——MethodChannel/EventChannel 的桥接层收口（Map → 强类型）、用 Pigeon 把双端契约做成编译期保障、PlatformView 嵌原生地图、把复用能力抽成了内部插件包；最后从一个 SwiftUI 原生 App 出发做了 add-to-app：CocoaPods 接入 module、引擎预热解决冷启动白屏、宿主通道打通双向通信和混合路由。
>
> **结果与判断**：Dart 侧通道逻辑全部有单测覆盖（不依赖模拟器），原生侧靠模拟器实跑冒烟。过程中踩了几个典型的坑——比如通道是绑引擎的、热引擎上 `setInitialRoute` 无效、引擎常驻导致状态不会自动重置——这些让我形成一个判断：**混合开发的成本不在写代码，在边界，所以边界要少、要清晰、要收口成一层。**

**可以主动亮出的证据**：十课文档 + 每课自测 + 双端对照实现 + 单测数量 + 真实踩坑记录。

---

## 八、反问面试官（挑 2~3 个）

1. 你们现在是 Flutter 独立 App 还是 add-to-app？如果是混合，引擎是单引擎还是多引擎？
2. 双端通信是手写 channel 还是上了 Pigeon / 自研的桥接框架？契约怎么保证不漂移？
3. Flutter 模块是和主工程一个仓库，还是独立仓库 + 产物集成？原生同学需要装 Flutter SDK 吗？
4. 混合栈路由是自己协调的，还是用了 flutter_boost 之类的框架？升级 Flutter 版本的节奏是怎样的？
5. Flutter 部分的性能和稳定性怎么监控？崩溃/异常有没有和原生打通到同一套看板？

（这几个问题本身就在展示你知道混合开发的真实难点在哪。）

---

## 九、考前 30 分钟速刷

- [ ] 卡 1 类型映射：**iOS 全是 NSNumber，Android 分裂 Integer/Long**
- [ ] 卡 2 三种 channel：**共用一个 messenger，只是协议约定不同**
- [ ] 卡 3 四条线程 + 三条线程纪律
- [ ] 卡 4 四种混原生形态：**盖住整屏 / 同屏共存 / 角色对调**
- [ ] 卡 5 引擎四铁律：**通道绑引擎、状态常驻、setInitialRoute 无效、谁 present 谁 dismiss**
- [ ] MethodChannel 五步链路能顺畅背出来
- [ ] `MissingPluginException` 六步排查顺序
- [ ] Pigeon 的一句话价值：**把运行期错误提前到编译期**
- [ ] PlatformView 的一句话代价：**把整块合成拆开了**
- [ ] 挑 2 个踩坑故事，按"现象→排查→根因→修法→引申"练一遍口述
