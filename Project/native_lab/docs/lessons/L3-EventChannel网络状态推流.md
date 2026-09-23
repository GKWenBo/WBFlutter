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

**6. 两个"看不见但会咬人"的细节。**

- **`receiveBroadcastStream()` 每调一次就是一条新流。** 它内部每次都新建一个 `StreamController`，第一个订阅者到来时才去原生 `listen`。所以**绝不能写在 `build()` 里**——页面每重建一次就换一条新流，`StreamBuilder` 会退订旧的、订阅新的，原生侧就是一串 `onCancel`/`onListen` 抖动（本课把它存成字段/在 `initState` 里取，正是为此）。同一条流上挂多个 `listen` 则**共享同一次原生订阅**，最后一个订阅者取消时才触发 `onCancel`。
- **EventChannel 没有背压（back-pressure）。** 原生推多快，Dart 就得收多快，框架不会替你限流。加速度计、滚动位置这类每秒几十上百次的源，**必须在原生侧节流/采样/聚合**再推（比如 100ms 合并一次），否则 UI 线程会被事件洪水淹掉。这条是"为什么不能把所有东西都做成流"的答案。
- 顺带一提原理：EventChannel **不是新的传输机制**——它就是在同一条 channel 上，`listen` 时发一条方法名为 `"listen"` 的 method call、取消时发 `"cancel"`，原生侧则通过同一条 channel 主动 `send` 消息把事件推回来。所以它和 MethodChannel 共用 codec 与信使。

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

## 七、面试高频题（附答案）

> 面试语境：问完 MethodChannel 一般紧接着就问"那持续的数据怎么传"。**选型判断 + 生命周期泄漏**是这一课的两个必答点。

**Q1. EventChannel 和 MethodChannel 怎么选？各举个场景。**

- **"做一次拿个结果" → MethodChannel**：读设备信息、埋点上报、调起支付、扫码（L4，虽然结果来得晚，本质仍是一问一答）。
- **"盯着一个会变的东西持续收" → EventChannel**：网络状态、电量、传感器、蓝牙扫描结果、下载进度、定位更新。

反面判断也要会说：**别用轮询代替流**（每 100ms `invokeMethod` 问一次，既费电又有延迟），也**别把一次性请求做成流**（多一套订阅生命周期要管，白白增加复杂度）。

**Q2. EventChannel 底层是怎么实现的？它是新的传输机制吗？**

不是。它和 MethodChannel 共用 `BinaryMessenger` 和 codec，只是**约定了两个方法名**：Dart 侧第一个订阅者到来时发一条 `"listen"`、取消时发一条 `"cancel"`；原生侧在 `onListen` 里拿到 `EventSink`，之后通过同一条 channel **主动 send** 消息把事件推回 Dart。

答出这一层，等于告诉面试官"我知道三种 channel 是同一根管子上的三种协议"。

**Q3. `onListen` / `onCancel` 什么时候触发？忘了 `onCancel` 会怎样？**

- `onListen`：Dart 侧**第一个** `listen` 时（`StreamBuilder` 挂载）。对应 iOS 的 `addObserver` / Combine 的 `sink`。
- `onCancel`：**最后一个**订阅者取消时（`StreamBuilder` dispose）。对应 `removeObserver` / `cancellable.cancel()`。

忘了在 `onCancel` 里拆监听 = **泄漏**：页面已经关了，`NWPathMonitor`/`NetworkCallback`/`CLLocationManager` 还在跑，持续耗电、持续往一个没人听的 sink 里推。定位、蓝牙这类高耗电的源，泄漏会直接体现在电量投诉上。

**Q4.（本课真踩过的 bug）页面第二次进入一直转圈，怎么排查？**

现象：首次订阅正常，退出再进就永远 `loading`。根因是**监听源在 `onCancel` 里被 `cancel()` 掉之后不可复用**（`NWPathMonitor` 一旦 cancel 就报废，`start()` 不再回调），而 handler 把它当成员变量反复用了。

修法：**`onListen` 里新建、`onCancel` 里销毁并置 nil**，别在 handler 初始化时建一个全局复用。

引申成通用原则：**凡是"一次性、cancel 后不可重启"的系统 API（很多都是），生命周期必须绑在订阅上，而不是绑在 handler 上。** 这是一个很好的"讲一个你排查过的疑难 bug"素材。

**Q5. 事件在后台线程产生，能直接往 `EventSink` 里推吗？**

不能。`NWPathMonitor.pathUpdateHandler`、Android 的 `NetworkCallback` 都在**非主线程**回调，而 channel 的通信要求在 **Platform 线程（主线程）**上进行。必须 `DispatchQueue.main.async { events(...) }` / `runOnUiThread { }` 切回去，否则行为未定义（轻则丢事件、重则崩）。

这和 L1 的"handler 在主线程、耗时活要挪走"是同一条线程纪律的两个方向：**耗时的挪出主线程，回调的挪回主线程。**

**Q6. EventChannel 有背压吗？高频事件（比如加速度计每秒 100 次）怎么办？**

**没有背压**，框架不限流，推多少收多少。高频源必须在**原生侧**处理：

1. **降采样**（传感器直接设采样率）；
2. **时间窗节流**（100ms 内只推最后一个值）；
3. **聚合成批**（攒 20 条打包成一个 List 推一次，减少过桥次数）；
4. 实在极端的（音频/视频帧）就别用 channel，走共享内存 / 纹理。

Dart 侧的 `throttle`/`debounce` 只能减轻 UI 重建压力，**过桥的开销已经付掉了**——所以节流要尽量做在源头。

**Q7. 原生侧怎么把"出错了"和"结束了"告诉 Dart？Dart 侧怎么接？**

- 出错：`events(FlutterError(code:message:details:))` → Dart 侧 `Stream` 的 **onError**（`StreamBuilder` 的 `snapshot.hasError`），收到 `PlatformException`。**注意：默认 `Stream` 收到 error 后订阅并不会自动结束**，后续还能继续收事件。
- 结束：`events(FlutterEndOfEventStream)` → Dart 侧 **onDone**（`StreamBuilder` 的 `ConnectionState.done`）。

UI 上要把三态都画出来：**loading（首帧无数据）/ data / error**——本课页面就是这么写的，这也是 `StreamBuilder` 最容易被忽略的一点：**首帧一定 `hasData == false`**。

**Q8. `receiveBroadcastStream()` 能在 `build()` 里调吗？**

不能。每次调用都新建一条流，`build` 一次就换一条 → `StreamBuilder` 退订旧的、订阅新的 → 原生侧 `onCancel`/`onListen` 反复抖动（监听源反复销毁重建，还可能触发 Q4 的复用 bug）。

正确做法：在 `initState` 里取一次存成字段，或者由桥接层持有一条共享流。**面试里能主动说出这一点，说明你真写过而不是看过。**
