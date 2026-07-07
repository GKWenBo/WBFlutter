# L3 EventChannel：原生持续推流

> 企业场景：网络状态监听——断网弹"网络不可用"、切蜂窝提示"当前非 Wi-Fi"、恢复自动重连。这类"状态会变、要持续收"的需求，MethodChannel 做不了（它只能你问一次答一次），于是有了 **EventChannel**。

## 一、本课要掌握什么

**1. EventChannel = 原生侧的一条 Stream。**

L1/L2 的 MethodChannel 是**请求-响应**：Dart `invokeMethod` 问一次，原生 `result` 答一次，`Future` 完成，结束。但"网络变了通知我"这种需求，你总不能每 100ms 问一次原生（轮询又费电又慢）。EventChannel 反过来——**Dart 订阅一次，原生想推就推**，是一条持续的数据流。

心智模型：
```
Dart:  channel.receiveBroadcastStream().listen(...)   // 订阅
  → 原生 onListen(events) 被触发：拿到 sink，开始监听系统网络
系统网络变化（wifi→none）
  → 原生 events("none")                                // 往 sink 推
Dart:  Stream 收到 "none" → StreamBuilder 重建 UI       // 自动刷新
Dart:  订阅取消（页面 dispose）
  → 原生 onCancel 被触发：拆掉网络监听
```

一句话：**EventChannel = 一条命名的、原生 → Dart 单向持续推送的 Stream**。

**2. ★ MethodChannel vs EventChannel（选型，本课核心）。**

| 维度 | MethodChannel（L1/L2） | EventChannel（L3） |
|---|---|---|
| 调用模型 | 请求-响应，一问一答 | 订阅-推送，持续收 |
| 方向 | Dart ⇄ 原生（可双向带返回） | 原生 → Dart 单向流 |
| Dart API | `invokeMethod()` → `Future` | `receiveBroadcastStream()` → `Stream` |
| 原生 API | `setMethodCallHandler` | `setStreamHandler`(`onListen`/`onCancel`) |
| 结果类型 | 单个 `Future` | 持续的 `Stream` 事件 |
| 典型场景 | 读设备信息、埋点上报（做一次） | 网络/电量/传感器/下载进度（持续变） |
| iOS 类比 | 一次异步调用（completion handler） | NotificationCenter observer / Combine Publisher |

**判断口诀**：**"做一次拿个结果" → MethodChannel；"盯着一个会变的东西" → EventChannel。**

**3. onListen / onCancel 生命周期（直接对标 iOS）。**

EventChannel 原生端就是实现一个 `FlutterStreamHandler`，两个方法：

| Flutter | 触发时机 | iOS 类比 | 该做什么 |
|---|---|---|---|
| `onListen(args, events)` | Dart 侧 `listen`（StreamBuilder 挂载） | `addObserver` / Combine `sink` | 拿住 `events`(EventSink)，启动监听源 |
| `onCancel(args)` | Dart 侧取消订阅（StreamBuilder dispose） | `removeObserver` / `AnyCancellable.cancel()` | 拆掉监听源，防泄漏 |
| `events(data)` | 你在事件发生时主动调 | 给 subscriber `send`/`post` | 把数据推给 Dart |

**忘了 onCancel 拆监听 = 泄漏**（页面关了 NWPathMonitor 还在跑），跟 iOS 忘 removeObserver 一个性质。

**4. 三个必踩的坑。**

- **sink 回调要切回主线程。** `NWPathMonitor` 的 `pathUpdateHandler` 在**后台队列**回调（Android 的 `NetworkCallback` 同理）。事件必须 `DispatchQueue.main.async { events(...) }` 回主线程再投——和 L1"handler 在主线程、耗时活要挪走"是同一个线程纪律的另一面。不切线程往 sink 推可能崩或行为未定义。
- **StreamHandler 要强引用。** iOS 侧 `NetworkStatusStreamHandler` 持有 `NWPathMonitor`，如果注册完就没人引用它，会被 ARC 回收 → 监听失效。所以 `NetworkBridge` 用一个 `static var handler` 把它挂住。
- **⚠️ 监听源不能跨订阅复用——每次 `onListen` 要新建（本课真实踩过的 bug）。** `NWPathMonitor` 一旦 `cancel()` 就报废、不能 `start()` 重启。症状：**页面第二次进入一直 loading**——第一次订阅正常，离开时 `onCancel` 把 monitor cancel 了，第二次订阅复用这个死 monitor，`start()` 不再回调，sink 永不吐值，`StreamBuilder` 卡在 `!hasData` 的转圈。修法：`onListen` 里 `let m = NWPathMonitor()` 每次新建，`onCancel` 里 `cancel()` 后置 `nil`。教训引申：**凡是"一次性、cancel 后不可复用"的监听源（很多系统 API 都这样），都要在 `onListen` 里创建、`onCancel` 里销毁，而不是 handler 初始化时建一个反复用。**（Android 侧本课没这问题，因为每次 `onListen` 都 new 了新的 `NetworkCallback`。）

**5. EventChannel 的 Dart 测试用 `setMockStreamHandler`（不是 MethodChannel 那套）。**

L1/L2 mock 原生用 `setMockMethodCallHandler`，对 EventChannel **不适用**。流要用 `defaultBinaryMessenger.setMockStreamHandler(channel, MockStreamHandler.inline(onListen: (args, events) {...}))`，在 `onListen` 里 `events.success(...)` 连推几条、`events.error(...)` 推错误、`events.endOfStream()` 收尾——就能不起模拟器测完整的流映射逻辑。

## 二、控件 / API 速查表

### Dart 侧

| API | iOS 类比 | 用法 & 关键点 | 坑 |
|---|---|---|---|
| `EventChannel(name)` | 一条命名的推送通道 | `const EventChannel('反域名/功能名')` | 名字三端一致 |
| `receiveBroadcastStream([args])` | 订阅 Publisher | 返回 `Stream`；一订阅触发原生 onListen | broadcast=多监听者共享 |
| `Stream.map()` | 转换流元素 | 把原生的 String 收口成 `NetworkStatus` 枚举 | 在桥接层收口，别让裸串进 UI |
| `StreamBuilder<T>` | 数据驱动的 UI | `stream:` + `builder:`，用 `snapshot.data/hasError` | 首帧 `hasData` 为 false，要处理 loading |

### Swift 侧

| API | iOS 类比 | 用法 & 关键点 |
|---|---|---|
| `FlutterEventChannel(name:binaryMessenger:)` | 推送通道的原生端 | `setStreamHandler(handler)` 挂处理器 |
| `FlutterStreamHandler` | observer 协议 | 实现 `onListen`/`onCancel` |
| `FlutterEventSink` | subscriber 的 send | `events(data)` 推数据、`events(FlutterError(...))` 推错、`events(FlutterEndOfEventStream)` 结束 |
| `NWPathMonitor`（Network.framework） | 系统网络监听 | `pathUpdateHandler` + `start(queue:)`；回调在后台队列 |

## 三、代码地图

> 注：下面反映**课后练习完成后**的当前代码——原生已从"推裸字符串"升级成"推 `Map{'type','level'}`"，Dart 侧多了 `NetworkInfo`。基础版（推 `String` → `NetworkStatus`）是本课主线讲解，练习把它升级到了 Map。

```
native_lab/app/lib/lessons/l3/
├── network_status.dart     # NetworkStatus 枚举 + fromRaw；NetworkInfo{status,level} + fromMap（课后练习）
├── network_bridge.dart     # NetworkBridge：包一条 EventChannel，statusStream() 返回 Stream<NetworkInfo>
└── l3_network_page.dart     # StreamBuilder 实时显示带色 banner（wifi绿/cellular橙/none红）+ _SignalBars 信号格

native_lab/app/ios/Runner/AppDelegate.swift
    ├── enum NetworkBridge              # 注册 + 强引用 handler
    └── class NetworkStatusStreamHandler # NWPathMonitor 监听，回主线程投 sink（推 Map）

native_lab/app/android/app/src/main/kotlin/.../MainActivity.kt
    └── EventChannel + ConnectivityManager.NetworkCallback  # Android 对照（推 Map）

native_lab/app/test/l3_network_test.dart  # 7 测：映射(枚举/Map)/流序列/单事件/error + 2 页面 widget test，全走 setMockStreamHandler
```

## 四、双端对照

| 对照点 | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| 监听 API | `NWPathMonitor`（Network.framework） | `ConnectivityManager.NetworkCallback` |
| 启动/停止 | `monitor.start(queue:)` / `monitor.cancel()` | `registerDefaultNetworkCallback` / `unregisterNetworkCallback` |
| 生命周期钩子 | `onListen` / `onCancel`（Flutter 统一命名） | `onListen` / `onCancel`（同名） |
| 线程 | 回调在后台队列 → `DispatchQueue.main.async` 投 sink | 回调非主线程 → `runOnUiThread` 投 sink |
| 权限 | 无需特殊权限 | 需 `ACCESS_NETWORK_STATE`（Manifest 默认含） |

## 五、自测清单

> 参考答案见 [自测答案/L3-自测答案.md](自测答案/L3-自测答案.md)（先自己答，再对照）。

1. EventChannel 和 MethodChannel 分别什么时候用？给两个各自的典型场景，说出判断口诀。
2. `onListen` / `onCancel` 分别在 Dart 侧什么动作时被触发？各对应 iOS 的什么 API？忘了 `onCancel` 会有什么后果？
3. 为什么 `NWPathMonitor` 回调里往 sink 推事件前要 `DispatchQueue.main.async`？不切线程会怎样？
4. 本课页面用 `StreamBuilder` 而不是 `StatefulWidget` 手动管订阅，`StreamBuilder` 替你托管了订阅的哪两件事？

## 六、课后练习

给状态流加"信号强度"——把原生推的从 `String` 升级成 `Map{'type': 'wifi', 'level': 3}`（复用 L2 的 Map 编解码本领）：
- Dart：`NetworkStatus` 之外加个 `NetworkInfo { NetworkStatus status; int level }`，`statusStream()` 改成 `Stream<NetworkInfo>`，`map` 里从 Map 取 `type`/`level`；
- Swift：`events(["type": status, "level": level])`（`NWPath` 拿不到真实强度就先写死或用信号占位）；
- 补一条 mock 流测试：`onListen` 里 `events.success({'type':'wifi','level':3})`，断言 `NetworkInfo.status==wifi && level==3`。

（提示：这题把 L2 的"复杂结构编解码"和 L3 的"流"合了起来——流里的每个事件也可以是 Map/List，codec 规则完全一样。）
