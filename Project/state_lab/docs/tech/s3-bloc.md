# s3 · Bloc：事件进、状态出的单向数据流

> StateLab 技术文档第三篇（S3 课配套）。地基原理见 [s1-状态管理的地基](s1-状态管理的地基.md)，Provider 对照见 [s2-provider](s2-provider.md)——本文假设你已读完它俩。
> 实战代码：`lib/versions/v2_bloc/`。

## 0. 一句话总纲

**Bloc 把"调方法改字段 + notifyListeners"翻转成"发事件 → 纯函数 → 不可变新状态 → emit"。**

S2 的 `CartModel` 是"你调 `add()`，它偷偷改 `_items` 再喊一嗓子"；Bloc 是"你 `add(事件)`，处理器算出一个**全新的**状态对象 `emit` 出来"。多写的样板（event 类型 + `copyWith` + `Equatable`）不是白交的——换来的正是 S2 自测答案练习 2 列的三样红利：**状态转移可 blocTest 断言值序列、可回放、可判等收窄重建**。这篇就把那张账单逐条兑现。

## 1. 心智模型与 iOS 类比

| Bloc 概念 | iOS 对应物 | 一句话 |
|---|---|---|
| 单向数据流 `Event → Bloc → State → UI` | Combine 的 `PassthroughSubject → map/scan → @Published → View` | 数据只朝一个方向流，UI 是状态的纯函数投影 |
| `Cubit`（方法直接 emit） | 一个能被订阅的 `ObservableObject`，方法里 `self.state = ...` | 去掉 event 层的轻量版，入门首选 |
| `Bloc`（`on<Event>` 注册处理器） | `Subject` 进、`scan` 攒状态、`sink` 出 | 事件流有转换需求（防抖/节流/丢弃）时才需要 |
| 不可变 `State` + `Equatable` | Swift `struct` 值语义 + `Equatable` | 状态是值，改 = 造新的，旧值留存可对比 |
| `EventTransformer` | Combine 的 `debounce`/`switchToLatest`/`flatMap(maxPublishers:)` | 声明"事件流怎么映射到处理器调用"（并发模型） |
| `emit` 相等短路 | SwiftUI `@Published` 的 `Equatable` diff（`removeDuplicates`） | 新旧状态 `==` 就不发，天然省一次重建 |

核心翻转：S2 世界里"改了什么"只有方法作者知道，监听者一律全量重查；Bloc 世界里"变了什么"是**两个不可变状态对象的可计算差**——`buildWhen: (prev, curr) => prev.x != curr.x` 这种声明式收窄，前提就是状态可判等。

## 2. API 全景速查表

| API | 用途 | 关键点 | 坑 |
|---|---|---|---|
| `Cubit<S>` | 轻量状态容器，方法直接 `emit` | 没有 event 层，像可订阅的 ViewModel | 有事件流转换需求（防抖）时它不够用 |
| `Bloc<E,S>` | 事件驱动 | `on<E>(handler, transformer:)` 注册；事件可被 transformer 加工 | 忘了注册 `on<E>` → 事件石沉大海 |
| `emit(newState)` | 推新状态 | **`newState == state` 时短路不发**（靠 Equatable） | state 用可变字段 → `==` 恒真/恒假，emit 被吞或该省没省 |
| `BlocProvider(create:)` | 新建 Bloc/Cubit 并托管 | pop/卸载**自动 close**；默认 lazy | create 里 read 本 bloc 自己 = 死循环 |
| `BlocProvider.value(value:)` | 复用已有实例（跨路由 re-provide） | **不托管 close**——谁建谁关 | 新建用它 = 没人 close；复用用 create = 被二次 close。铁律同 Provider |
| `RepositoryProvider<T>` | 纯 DI（服务/仓库/客户端） | = Provider 的 `Provider<T>`，bloc 世界的惯用名 | 想让 UI 随它变？它不是干这个的，那是 Bloc 的活 |
| `MultiBlocProvider` / `MultiRepositoryProvider` | 多个平铺 | 纯语法糖，等价嵌套 | 顺序有意义：后者能 read 前者 |
| `BlocBuilder<B,S>` | 订阅重建 | `buildWhen:(prev,curr)=>bool` 收窄 | buildWhen 里做副作用（不该在这弹窗） |
| `BlocSelector<B,S,R>` | 字段级订阅 | 选出 R，`==` 变了才重建（= Provider 的 Selector） | R 选可变引用 → 永不/次次重建 |
| `BlocListener<B,S>` | **副作用**（弹窗/导航/SnackBar） | 只跑一次副作用不重建 UI；`listenWhen` 收窄 | 把副作用写进 builder → 一次重建放一次 toast |
| `BlocConsumer<B,S>` | builder + listener 合体 | 一个 widget 同时要重建又要副作用时用 | 只需其一时别用它，拆开更清楚 |
| `context.read<B>()` | 拿 bloc 调 `add`/方法 | 回调里用 | build 里滥用不跟新 |
| `context.watch<B>()` | 取值 + 订阅整个 state | = `BlocBuilder` 的 context 版 | 回调里调抛错 |
| `context.select<B,R>()` | 字段级订阅 | = `BlocSelector` 的函数式写法 | 集合引用坑同上 |

### 2.1 EventTransformer 与并发模型（Bloc 独有的那块拼图）

`on<E>` 默认按 `concurrent()` 处理事件——每个事件立刻起一个处理器，互不等待。真实业务里"连打的事件"往往需要别的语义，靠 `bloc_concurrency` 四选一：

| transformer | 语义 | Combine 类比 | MiniShop 用在哪 |
|---|---|---|---|
| `concurrent()`（默认） | 全部并行 | `flatMap` | 无（会导致重复请求） |
| `sequential()` | 排队，一个做完下一个 | `flatMap(maxPublishers: .max(1))` | 无（过期结果会覆盖新结果） |
| `droppable()` | 正在处理时，新来的**丢弃** | `flatMap` + 忙时忽略 | **LoadMore**：一次没跑完，期间的触底事件直接扔 |
| `restartable()` | 新事件来就**掐掉旧处理器** | `switchToLatest` | **Search**：改词就取消上一枪 |

搜索页还要再叠一层去抖，所以自定义组合（`stream_transform` 的 `debounce` + `restartable`）：

```dart
EventTransformer<E> _debounceRestartable<E>(Duration d) =>
    (events, mapper) => restartable<E>().call(events.debounce(d), mapper);
```

**一个 transformer 一锅端了 v1 的两坨手写**：`Timer` 防抖 → `debounce`；请求序号丢过期 → `restartable`（新事件到就 switchMap 取消旧处理器，旧响应回来时 `emit` 已是 no-op）。

## 3. MiniShop 实战导读：v1 Provider 的每一行 → Bloc 对应物

对照命令：`git diff <S2收官>..<S3> -- state_lab/lib/versions/`，或并排开 `v1_provider/` 与 `v2_bloc/`。

| v1 Provider | v2 Bloc | 帮你干了什么 / 差在哪 |
|---|---|---|
| `Provider<ProductApi>`（纯 DI） | `RepositoryProvider<ProductApi>` | 同一件事，bloc 世界的惯用名 |
| `ChangeNotifierProvider(create: ..loadFirst())` | `BlocProvider(create: ..add(Started()))` | 同样托管生命周期；"开载"从调方法变成发事件 |
| `ChangeNotifierProvider.value` | `BlocProvider.value` | 同一条 create/.value 铁律 |
| `MultiProvider` | `MultiBlocProvider`/`MultiRepositoryProvider` | 语法糖，一样 |
| `Consumer<Model>`（body） | `BlocBuilder<Bloc,State>` | BlocBuilder 多了 `buildWhen` 这道闸 |
| `Selector<CartModel,int>`（角标） | `BlocSelector<CartCubit,CartState,int>` | 同粒度、同 `==` 判定 |
| 详情 `context.select` | `context.select<CartCubit,int>` | 一样 |
| 购物车页 `context.watch` | `BlocBuilder<CartCubit,CartState>`（整页） | 一样的整页粒度 |
| 一切回调 `context.read<Model>()` | `context.read<Bloc>()` | 一样 |
| —（v1 副作用内联在回调） | `BlocListener`/`BlocConsumer`（搜索失败 toast） | Bloc 把"副作用"单列一类 widget |
| `notifyListeners()` + 改字段 | `emit(不可变新状态)` | 状态可判等、可回放，代价是 copyWith 样板 |
| `_disposed` 守卫（模型侧 mounted） | —（bloc close 后 `emit` 自动 no-op / 处理器订阅注销） | **守卫这活 Bloc 帮你干了**（见 §4.4） |
| 手写 `Timer` 防抖 + 请求序号 | `debounce + restartable` 一个 transformer | 输入流处理从手搓变声明式 |
| `if (_loadingMore) return;` 布尔守卫 | `droppable()` transformer | 防重入从命令式变声明式 |

三个状态件的选型（v2 骨架）：

- **`CartCubit`（Cubit）**：购物车增删是简单的"方法 → 新状态"，没有事件流转换需求 → 用轻量的 Cubit。版本级共享，挂 V2ShopRoot。
- **`ProductListBloc`（Bloc）**：列表有 Started/Refreshed/LoadMore 三种事件，且 LoadMore 要 `droppable` → 用 Bloc。页面级，pop 即 close。
- **`SearchBloc`（Bloc）**：输入流要 `debounce + restartable` → 必须 Bloc。页面级。
- **页面私有**：收藏心形、TextEditingController → 继续 setState/State，"一个人看的状态不上树"，五版一致。

不可变 `CartLine` vs 可变 `CartItem`：v2 在 `state/cart_state.dart` 里另起了一个**不可变** `CartLine`（`Equatable` + `copyWith`），刻意不复用 shared 那个可变 `CartItem`。S2 靠 `List.unmodifiable` 运行时堵门，是防御；不可变状态是**类型级根治**——字段全 `final`，想改只能 `copyWith` 出新对象。这就是练习 2 说的"copyWith 税"，交税换回值语义 `==`。

## 4. 底层原理：撕开 Bloc 的封装

1. **Bloc 就是一个 `Stream<State>` + 一个 `StreamController<Event>`**。`on<E>(handler)` 把"事件类型 E → handler"登记进一张表；事件从 `add` 进入 event 流，经 `transformer` 加工后驱动 handler；handler 里的 `emit` 把新状态推进 state 流。`BlocBuilder` 就是订阅这条 state 流的 `StreamBuilder`。整套东西是 Dart Stream 的直接封装，无私有魔法（和 Provider 骑在 InheritedWidget 上是同一种"薄封装"哲学）。
2. **`emit` 的相等短路**：`emit(newState)` 内部 `if (newState == state) return;`。这里的 `==` 就是 `Equatable` 给的值语义——**这就是不可变 + 值语义省下的那次重建**：两个内容相同的 state，UI 一次都不用抖。反过来，如果 state 里塞了可变字段（比如直接持有那个会被就地改的 `List`），`==` 要么恒真（emit 被吞，界面不更新）、要么恒假（该省的没省），两个方向的 bug 都在这。
3. **buildWhen / BlocSelector 的二次收窄**：state 流推来新状态后，`BlocBuilder` 先跑 `buildWhen(prev, curr)`（默认恒 true），返回 false 就不重建；`BlocSelector` 则先跑 `selector` 取出 R 再比 `==`。**先收到通知、再决定要不要重建**——与 Provider 的 Selector 结构完全同构，只是数据来源从 Listenable 换成 Stream。
4. **close 后为什么不用 `_disposed` 守卫**：`Emitter` 在处理器完成或 bloc `close` 后进入 `isDone`，此时 `emit` 变 no-op（`restartable`/`droppable` 还会主动取消旧处理器的订阅）。所以 v1 里"页面 pop 后在途请求回来撞 used-after-disposed"的病，Bloc 侧由框架接管了——**这正是 Bloc 帮你干的脏活之一**。要在 handler 里手动判时用 `if (isClosed) return;`（对应 v1 的 `_disposed`），但 MiniShop 的三个 bloc 都靠 transformer/emitter 语义天然安全，没写显式守卫。
5. **EventTransformer 决定事件→处理器的映射方式**：它是一个 `(Stream<E>, EventMapper<E>) → Stream` 函数。`concurrent` 用 `flatMap`、`sequential` 用 `asyncExpand`、`restartable` 用 `switchMap`、`droppable` 忙时忽略——本质是选一个 Rx 高阶算子。防抖之所以放这里而不放 UI 层：**事件流是 Bloc 的一等公民**，去抖是对流的变换，天然属于这一层；放 TextField 里 setState 计时是把流逻辑漏进了视图。

## 5. 优缺点、适用场景、常见坑

**定位**：中大型 App / 多人协作 / 业务逻辑复杂或异步编排多的项目。强制的"事件→状态"仪式感带来纪律：所有状态变更都有名字（事件）、都可追踪（state 序列）、都可测试（blocTest）、都可回放（time-travel）。代价是几个方案里**样板最多**——每个状态件要 event 类型、要 state 的 `copyWith`、要 `Equatable` 的 props。小页面用 Bloc 有杀鸡用牛刀之感（所以有 Cubit 这个轻量档）。

**坑清单**（前四条 = 面试和生产事故高发区）：

1. **state 用了可变字段**：`Equatable` 的值语义被破坏，`emit` 的相等短路要么吞掉更新、要么形同虚设。状态必须真不可变。
2. **`Equatable` 的 props 漏字段**：漏了的字段变化时 `==` 仍判等 → `emit` 被短路 → 界面不更新。props 要覆盖所有参与相等判断的字段。
3. **在 builder 里做副作用**：弹 SnackBar / 导航 / 埋点写进 `BlocBuilder.builder`，一次重建放一次。副作用挪到 `BlocListener`（`listenWhen` 限定触发时机）。
4. **EventTransformer 选错**：该 `droppable` 用了 `concurrent` → 触底两次发两次请求、重复追加；该 `restartable` 用了 `sequential` → 快速改词时旧结果覆盖新结果的过期 bug。（讲义课后练习 ①② 让你亲手复现这两个。）
5. **create/.value 用反**：同 Provider——`.value` 包新建对象无人 close 泄漏；`create` 包已有对象被二次 close。
6. **handler 里 await 后长时间不 emit 撞 close**：极端情况下需 `if (isClosed) return;` 守卫（本工程靠 transformer 语义规避）。

## 6. 面试高频题（答案要点）

1. **Cubit 和 Bloc 区别，怎么选？** Cubit 无 event 层、方法直接 emit，轻量；Bloc 事件驱动、可挂 EventTransformer。有事件流转换需求（防抖/节流/丢弃/排队）就用 Bloc，否则 Cubit。MiniShop：购物车 Cubit，列表/搜索 Bloc。
2. **Bloc 的单向数据流四要素？** Event（意图）→ Bloc（`on<E>` 处理器，纯函数式转移）→ State（不可变值）→ UI（状态的纯函数投影）。数据单向、UI 无本地可变状态。
3. **`emit` 一个和当前值相等的 state 会怎样？和 Equatable 什么关系？** 短路，不发不重建。判等靠 state 的 `==`，`Equatable` 就是来提供值语义 `==`/`hashCode` 的——这是不可变状态省重建的机制根源。
4. **buildWhen / BlocSelector / BlocListener 各解决什么？** buildWhen：state 变化后决定要不要重建（整块收窄）；BlocSelector：选一个字段比 `==`（字段级收窄）；BlocListener：状态变化时跑**副作用**（弹窗/导航），不重建 UI。
5. **EventTransformer 是什么？四种并发语义？** 决定事件流如何映射到处理器调用的函数。concurrent（并行/flatMap）、sequential（排队/asyncExpand）、droppable（忙时丢弃）、restartable（新事件掐旧/switchMap）。
6. **防抖为什么用 EventTransformer 而不在 UI 层做？** 事件流是 Bloc 的一等公民，去抖是对流的变换，属于状态层；放 UI 层是把流逻辑漏进视图，且不可单测。
7. **droppable 和 restartable 分别替了 v1 的哪行手写？** droppable ← `if (_loadingMore) return;` 布尔防重入；restartable ← 请求序号丢过期（配 debounce 再替掉 `Timer`）。
8. **BlocProvider create vs value？** 新建托管用 create（自动 close），复用已有用 value（不托管）。用反的两种事故要能说。
9. **RepositoryProvider 和 BlocProvider 区别？** RepositoryProvider 是纯 DI（放服务/仓库，UI 不随它变），BlocProvider 放 Bloc/Cubit（UI 随 state 变）。前者 = Provider 的 `Provider<T>`。
10. **不可变状态相比可变模型换来什么、代价是什么？（S2 练习 2 正式答案）** 换来：可 diff/判等（声明式 buildWhen 才可能）、可回放（状态序列 = 完整录像，blocTest 断言值）、类型级杜绝"绕过通知偷偷改"。代价：每个 state 要 copyWith + 值语义 `==`（Equatable/freezed 减负），改一个字段要整体复制替换，心智从"调方法"换成"事件进、状态出"。
