# s6 · Riverpod：搬出树的 Provider，编译期安全的依赖图

> StateLab 技术文档第六篇（S6 结课配套），补齐"每方案一篇深度文档"的最后一块。前置：[s1-地基](s1-状态管理的地基.md) · [s2-provider](s2-provider.md)（必读——Riverpod 就是冲着它的三条上限来的）· 横向定位见 [s5 §0](s5-横向对比与选型.md)。
> 实战代码：`lib/versions/v4_riverpod/`（手写 Notifier 版；WanShop 用的 codegen 版与之等价，见 §2.1）。

## 0. 一句话总纲

**Riverpod = 把 Provider 的注册表从 Widget 树里搬出来，用"顶层 final 常量 + 泛型"换来编译期存在性保证，再把异步三态（AsyncValue）和生命周期（autoDispose）内建成类型。**

S2 结尾留了 Provider 的三条上限：①缺失运行时才炸（ProviderNotFoundException）；②对象间组合靠 ProxyProvider 手拼；③逻辑绑死 context。Riverpod（作者同一人，名字就是 Provider 重排字母）逐条回答：①provider 是顶层 `final` 常量——**引用即存在**，编译器保证；②provider 之间 `ref.watch` 互相依赖，组合是一等公民；③`Ref` 替代 context，状态层是纯 Dart，测试连 Widget 都不用 pump。

与 GetX 的分野一句话（S4 练习 3 的答案）：同是"搬出树"，GetX 搬进了**运行时全局可变 Map**（谁都能 put/delete/覆盖，find 靠祈祷），Riverpod 搬进了**编译期声明的不可变 provider 图**（图的节点是常量，实例的容器由 ProviderScope 圈定）。

## 1. 心智模型与 iOS 类比

| Riverpod 概念 | iOS 对应物 | 一句话 |
|---|---|---|
| provider 图（顶层 final 常量们） | 一张编译期就画好的依赖图（≈ Swift 里用 KeyPath 声明的 DI 图） | 节点是"怎么造"，不是实例 |
| `ProviderScope` / `ProviderContainer` | DI 容器实例 | 图是蓝图，Scope/Container 是照图施工的工地；两个 Scope 两套实例 |
| `Notifier<T>` | `ObservableObject` 的纪律版 | "Cubit 的 riverpod 版"：方法直接给 `state` 赋不可变新值 |
| `AsyncNotifier<T>` | 一个自带 loading/error/data 的 ViewModel | **build 即首载**，三态由 AsyncValue 类型内建 |
| `AsyncValue<T>` | Swift 的 `Result` + loading 态的和类型 | 穷尽匹配，忘处理 error 编译器提醒 |
| `ref.watch` / `ref.read` / `select` | `@EnvironmentObject` / 取值不观察 / 观察单个属性 | 与 Provider 的 watch/read/select 逐位对应，只是主语从 context 换成 ref |
| `autoDispose` | 引用计数（无人持有即释放） | "还有没有人 watch"替代"挂在哪棵子树" |
| `overrides` | 测试注入的协议替身 | 生产/测试同一个注入口 |

**核心翻转**：Provider 世界里"作用域"由**挂树位置**决定（版本级挂根、页面级挂页头）；Riverpod 世界里作用域由**两样东西**决定——容器边界（ProviderScope 圈哪）+ 生命周期策略（autoDispose 与否）。位置问题变成了声明问题。

## 2. API 全景速查表

| API | 用途 | 关键点 | 坑 |
|---|---|---|---|
| `Provider<T>` | 只读依赖/服务/配置 | 纯 DI（v4 的 productApiProvider、searchDebounceProvider） | 想要可变状态别用它，换 Notifier |
| `NotifierProvider<N,S>` | 同步可变状态 | `Notifier.build()` 给初值；方法里 `state = 新值` | `state` setter 有 `==` 短路——state 必须真不可变（Equatable 又上岗） |
| `AsyncNotifierProvider<N,S>` | 异步状态 | `Future<S> build()`——**build 即首载**；state 是 `AsyncValue<S>` | 局部失败（加载更多）别打成 AsyncError，在 data 里建模（v4 loadMore 的注释） |
| `.autoDispose` 修饰 | 页面级生命周期 | 最后一个监听者离场即销毁；`ref.keepAlive()` 可豁免 | 测试里 `container.read` 完就没人监听了——要 `container.listen` 保活 |
| `.family` 修饰 | 带参 provider | `provider(id)` 每个参数一份实例 | 参数要有值语义 `==`，否则实例失控增殖 |
| `ref.watch(p)` | 订阅 | build 里用；provider 之间互 watch 构成依赖图 | 回调里 watch 抛错（同 Provider 铁律） |
| `ref.read(p)` / `ref.read(p.notifier)` | 取值 / 拿 notifier 调方法 | 回调里用 | build 里滥用不跟新 |
| `ref.watch(p.select((s) => x))` | 字段级订阅 | = Provider 的 select / Bloc 的 BlocSelector | 集合引用坑同款：选标量或不可变值 |
| `ref.listen(p, (prev, next) {})` | **副作用**（弹窗/导航） | = BlocListener 的 riverpod 版 | 副作用别写进 build |
| `ref.invalidate(p)` / `ref.refresh(p.future)` | 重跑 build | refresh 返回新一轮 future（RefreshIndicator 直接喂） | invalidate 后立刻 read 可能拿到旧值，要新值用 refresh |
| `ref.onDispose(fn)` | 销毁钩子 | Timer/订阅的清理挂这（v4 SearchNotifier） | 忘挂 = 悬垂 Timer（S0 的老病） |
| `ProviderScope(overrides:)` | 容器入口 + 注入 | 生产/测试同口子（v4 root 注 Dio，测试注 Fake） | 嵌套 Scope 是新容器：跨路由要 `UncontrolledProviderScope` 共享（§4.4） |
| `ProviderContainer` | 无 UI 的容器 | 纯 Dart 测状态层 | 记得 dispose；riverpod 3 测失败态要关自动重试（§4.5） |

### 2.1 手写版 vs codegen 版（WanShop 同款对照）

v4 用手写版是刻意的——概念裸露，diff 信号最强。codegen 版（`riverpod_annotation` + `riverpod_generator` + build_runner）只是把"声明 provider 那一行"自动生成：

```dart
// 手写（v4 现状）
class CartNotifier extends Notifier<CartState> { ... }
final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);

// codegen（WanShop 姿势）：注解替声明，g.dart 里生成同样的 provider
@riverpod
class Cart extends _$Cart {
  @override CartState build() => const CartState();
  ...
}
// 生成物：cartProvider（还自动帮你选 autoDispose 当默认、family 参数变 build 形参）
```

差异清单：codegen 默认 **autoDispose**（keepAlive: true 才常驻——与手写默认相反，迁移高频坑）；family 参数直接写成 build 的形参；泛型样板消失。**运行时行为零差别**——读完本文的手写版，codegen 版只是换了件外套。

## 3. MiniShop 实战导读：v1/v2/v3 的每一行 → Riverpod 对应物

对照命令：`git diff <S5收官>..<S6> -- state_lab/lib/versions/`，或并排开 `v1_provider/` 与 `v4_riverpod/`。

| 前三版 | v4 Riverpod | 差在哪 |
|---|---|---|
| v1 `Provider<ProductApi>` 挂树 / v3 `Get.put` | 顶层 `productApiProvider` + Scope `overrides` 注入 | 声明与注入分离；默认实现直接 throw——忘 override 第一时间炸在明处 |
| v1 `create: ..loadFirst()` / v2 `..add(Started())` | **没有这行**——`AsyncNotifier.build` 即首载 | "创建即加载"成了类型语义，级联调用样板消失 |
| v1/v2/v3 手搓 loading/error/status 字段 | `AsyncValue` 内建三态 | 三态是类型不是字段；局部失败在 data 里建模（loadMore 注释） |
| v1/v2 页面级 create（pop 即 dispose）/ v3 手动 put/delete | `.autoDispose` | 判据从"挂哪/谁删"换成"还有没有人 watch" |
| v1 Selector / v2 BlocSelector | `ref.watch(p.select((s) => s.totalCount))` | 同一粒度同一 `==` 判定 |
| v1/v2 每条 push `.value` / v3 免疫 | `pushWithScope`（UncontrolledProviderScope 共享容器） | 容器不在树上，但 **Scope 入口在树上**——路由挂 Navigator 下的老问题换了个形态回来（§4.4） |
| v1 `_disposed` / v2 框架接管 / v3 `isClosed` | `ref.onDispose` 挂清理 + autoDispose 兜底 | 防抖 Timer 的清理声明在 build 里，销毁自动执行 |
| v2 EventTransformer 防抖+丢过期 | **手写 Timer + 序号（v1 同款回归）** | riverpod 管"状态怎么共享"不管"事件流怎么编排"——Bloc 独门优势再次验证（s5 §1.2） |
| 防抖时长硬编码/构造注入 | `searchDebounceProvider` | **配置也是依赖**：测试 override 成 30ms，与 api 注入同一口子 |

三个状态件的作用域声明（v4 骨架）：

- **`cartProvider`（无 autoDispose）**：版本级——只要 V4 的 Scope 活着就活着，退出版本 = Scope dispose = 状态清零（版本隔离由容器边界兜底，不是由"挂根"兜底）。
- **`productListProvider` / `searchProvider`（autoDispose）**：页面级——页面 pop、最后一个 watch 消失，销毁重置；重进页面重建重载。
- 页面私有（收藏心形、TextEditingController）照旧 setState/State——五版一致的铁律最后一次出场。

## 4. 底层原理：撕开 Riverpod 的封装

1. **provider 常量不是实例，是"节点定义"**：`final cartProvider = NotifierProvider(...)` 只记录"类型 + 怎么造 + 什么策略"，本身无状态、可全局共享。实例（`ProviderElement`）住在 `ProviderContainer` 的一张表里，key 就是 provider 常量的**对象标识**——所以"引用即存在"：你能 import 到这个常量，容器就一定能造出实例，不存在 GetX 的"find 时才发现没 put"。
2. **依赖图与自动重算**：provider 的 build 里 `ref.watch(另一个 provider)`，容器就记一条边；上游变化，下游按拓扑序重跑 build——这就是 ProxyProvider 手拼的"对象间依赖"在 Riverpod 里变成一等公民的机制。UI 的 `ref.watch` 只是这张图的叶子节点（ConsumerWidget 的 Element 作为监听者挂上去）。
3. **autoDispose = 引用计数**：每个 ProviderElement 数着自己的监听者（UI watcher、下游 provider、container.listen）；autoDispose 的节点在计数归零时进销毁队列（微任务后生效，所以测试里 `sub.close()` 后要 `await Duration.zero` 才能观察到重建——v4 测试注释）。`ref.keepAlive()` 本质是挂一个不会消失的假监听者。
4. **为什么还要 UncontrolledProviderScope**：容器确实不在树上，但 UI 要找到"我该用哪个容器"——靠的还是 `ProviderScope` 这个 InheritedWidget。push 的路由挂在 Navigator 下、不在 V4ShopRoot 的 Scope 子树里，`ref` 向上找 Scope 会找到别人（或没有）。`UncontrolledProviderScope(container: ...)` 把**同一个容器**再挂到新路由头顶（只引用不拥有，不会二次 dispose）。真实单方案 App 把 ProviderScope 包在 runApp 最外层就根治——和 S2 §5.6"提到 MaterialApp 之上"是同一道取舍题，StateLab 为五版隔离两次都选了"压在版本根 + 每条 push 补一层"。
5. **riverpod 3 的两个新脾气**（本工程实测踩到）：①`valueOrNull` 并进 `value`（可空；错误态仍保留旧数据便于"错误时显示旧列表"类 UI）；②**自动重试**——build 抛错默认按指数退避自动重跑，生产免费健壮性，测试抓 AsyncError 必须 `ProviderContainer(retry: (count, err) => null)` 关掉（`product_list_notifier_test.dart` 有现场）。
6. **`state =` 的判等短路**：Notifier 的 state setter 用 `==` 比新旧值，相等不通知——与 Bloc 的 emit 短路同一机制，Equatable 在 v4 的 CartState 上第三次上岗（v2/v4 同款，对照 v3 的 Rx 写入端去重只护 Rx 盒子不护派生值）。

## 5. 优缺点、适用场景、常见坑

**定位**：新项目无历史包袱、异步状态是主要复杂度来源、想要编译期安全——Riverpod 是当前官方生态的推荐终点（Provider 作者明言 Riverpod 是其精神续作）。相对 Bloc：纪律感弱一档（没有强制的事件层），换来样板少一档；输入流编排（防抖/节流）不如 Bloc 的 transformer 优雅。相对 Provider：概念多一层（ref/容器/修饰符），学习曲线换上限。

**坑清单**（高频排序）：

1. **codegen 与手写的 autoDispose 默认值相反**：codegen 默认 autoDispose，手写默认常驻——混用时状态"莫名消失/莫名残留"多半是它。
2. **autoDispose 提前销毁**：async 回调里最后一个 watcher 已离场，provider 没了——需要跨页存活的别标 autoDispose，或 `ref.keepAlive()`。
3. **局部失败打成 AsyncError**：loadMore 失败整页掉错误态（v4 code review 第 1 条）——AsyncError 只表达"整体失败"。
4. **select 选可变引用**：同 Provider/Bloc 的老坑，第三次出现，选标量。
5. **回调里 ref.watch**：抛错，改 read（铁律跨方案通用）。
6. **测试忘保活/忘关重试**：autoDispose 测试要 `container.listen`；失败态测试要 `retry: (c, e) => null`。
7. **在 build 外持有 ref 的产物**：Notifier 的字段里存 `ref.read` 来的对象没问题，但存"watch 的结果"会失去响应性——依赖要在 build 里声明。

## 6. 面试高频题（答案要点）

1. **Riverpod 解决了 Provider 的哪三个问题？怎么解决的？** 缺失运行时炸 → provider 是顶层常量引用即存在；组合靠 ProxyProvider 手拼 → provider 间 ref.watch 构成依赖图自动重算；逻辑绑 context → Ref 替代 context，状态层纯 Dart。
2. **provider 常量和实例什么关系？** 常量是节点定义（怎么造+策略），无状态可全局；实例住 ProviderContainer 的表里，以常量的对象标识为 key。两个 Scope 两套实例。
3. **Notifier / AsyncNotifier 怎么选？和 Cubit 像在哪？** 同步状态 Notifier，有异步首载 AsyncNotifier（build 即首载）。像 Cubit：无事件层、方法直接产新状态；差别在挂靠处（树 vs 图）和三态（自建 vs AsyncValue 内建）。
4. **AsyncValue 比自维护 loading/error 字段好在哪？** 三态是和类型可穷尽匹配，忘处理编译器提醒；错误态保留旧数据；isRefreshing 等细分免费送。局限：只表达"整体"三态，局部失败要在 data 里建模。
5. **autoDispose 的机制与例外？** 引用计数归零即销毁（微任务后生效）；keepAlive() 挂假监听者豁免；codegen 默认开、手写默认关。
6. **watch / read / select / listen 的分工？** watch 订阅（build 限定）；read 取值/拿 notifier（回调）；select 字段级判等；listen 副作用（= BlocListener）。与 Provider 五件套逐位对应。
7. **ref.invalidate 和 ref.refresh 区别？** 都重跑 build；refresh 额外返回新一轮的值/future（RefreshIndicator 直接喂），invalidate 后立刻 read 可能拿到旧值。
8. **Riverpod 和 GetX 同为"搬出树"，安全性差在哪？** 运行时全局可变 Map（put/find/delete 谁都能动，类型是查表 key）vs 编译期声明的不可变图（节点是常量，泛型静态保证，容器边界显式）。
9. **跨路由为什么还要 UncontrolledProviderScope？** 容器不在树上，但找容器的入口（ProviderScope=InheritedWidget）在树上；push 的路由不在 Scope 子树里。根治法 = Scope 提到 MaterialApp 之上（本工程为版本隔离不采用）。
10. **riverpod 3 的自动重试是什么？测试怎么办？** build 失败按指数退避自动重跑；测试断言失败态前用 `ProviderContainer(retry: (c, e) => null)` 关掉，否则 AsyncError 一闪而过抓不到。
11. **codegen 版和手写版差别？** 运行时零差别；codegen 少写 provider 声明与泛型、family 参数变 build 形参、**默认 autoDispose**（高频坑）。
12. **什么时候不选 Riverpod？** 存量 Provider 项目痛点不在其上限（迁移收益<成本）；团队要强事件纪律/输入流编排密集（Bloc 更合适）；极小项目（setState/Provider 够用，s5 决策树第一分叉）。
