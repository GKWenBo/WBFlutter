# Riverpod 实现原理 —— 源码级拆解(iOS 视角)

按你熟悉的"概念迁移"路径,先给一张总映射表,再逐层拆到源码机制。

## 一、核心心智模型:全局的 Provider 为什么不是全局状态

```dart
final counterProvider = NotifierProvider<Counter, int>(Counter.new);
```

这行全局变量常被误解为"全局单例状态"。实际上:

| Riverpod 概念       | 本质                                                         | iOS/SwiftUI 类比                                             |
| ------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| `Provider`          | **不可变的配方/键**,只描述"如何创建状态"                     | `EnvironmentKey`(只定义键和默认值,不存值)                    |
| `ProviderContainer` | **真正持有状态的容器**                                       | `EnvironmentValues` 存储 / DI Container                      |
| `ProviderElement`   | 某个 Provider 在某个容器中的**运行时实例**(状态+订阅者+生命周期) | Flutter 三树里 Widget→Element 的关系,或 `@StateObject` 背后的 storage |
| `Ref`               | Element 对外暴露的受控句柄                                   | 类似 `EnvironmentValues` 的受限访问接口                      |

关键推论:**同一个 Provider 在两个不同的 `ProviderContainer` 中,状态完全隔离**。这就是测试时 `ProviderContainer(overrides: [...])` 能工作的根基——Provider 是键,容器才是存储。这与 Flutter 三树的 "Widget 是配置、Element 是实例" 完全同构,你可以直接套用那套心智模型。

## 二、三层架构与惰性初始化

```
Provider (配方, 全局不可变)
   │  container 首次 read/watch 时
   ▼
ProviderElement (状态容器 + 依赖图节点 + 生命周期)
   │  调用 provider 的 create 函数
   ▼
State (真正的值, 包在 element._state 里)
```

源码路径大致是:

```dart
// 伪代码,概括 ProviderContainer.read 的流程
T read<T>(ProviderListenable<T> provider) {
  final element = _getOrCreateElement(provider); // 惰性: 不存在才创建
  element.flush();      // 若被标记 dirty,先重算
  return element.requireState;
}
```

要点:

- **惰性求值**:Element 只在第一次被 read/watch 时创建并执行 `build()`。类比 SwiftUI 的 `@Environment` 也是访问时才解析,而不是声明时。
- `_getOrCreateElement` 内部本质是一个 `HashMap<Provider, ProviderElement>` 查找——这就是为什么 Provider 必须是**顶层 final 变量**:它的 identity(内存地址)就是 map 的 key。如果你在 build 方法里动态创建 Provider,每次都是新 key,状态永远命中不了。⚠️ 这是面试高频陷阱题。

## 三、ref.watch 的订阅机制:一张有向依赖图

Riverpod 内部维护的是一个 **DAG(有向无环依赖图)**,节点是 ProviderElement,边由 `ref.watch` 建立:

```dart
final filteredTodos = Provider((ref) {
  final todos = ref.watch(todosProvider);   // 建边: todosProvider → filteredTodos
  final filter = ref.watch(filterProvider); // 建边: filterProvider → filteredTodos
  return todos.where(filter.apply).toList();
});
```

`ref.watch` 做了两件事:

1. **返回当前值**(内部走 read 路径);
2. **注册订阅**:在被 watch 的 Element 上添加一个 `ProviderSubscription`,同时在自己身上记录依赖。

当 `todosProvider` 状态变化时的传播流程:

```
todosProvider 状态变化
  → 遍历其 subscriptions,标记下游 Element 为 dirty
  → 下游不会立即重算(除非有 listener 主动 flush)
  → 在下一次被读取 / 下一帧时,dirty Element 重新执行 build()
  → 若新值 == 旧值 (updateShouldNotify,默认 identical/==),传播终止 ✂️
```

两个和 SwiftUI 对照的关键点:

| 机制         | Riverpod                                   | SwiftUI                                                      |
| ------------ | ------------------------------------------ | ------------------------------------------------------------ |
| 依赖收集方式 | **显式**:`ref.watch` 手动声明              | **隐式**:`@Observable` 的 access tracking,body 里读到哪个属性就依赖哪个 |
| 变更传播     | 沿依赖图逐层标 dirty,惰性重算,值相等则剪枝 | 依赖失效 → body 重算,diff 后决定渲染                         |
| 剪枝粒度     | `select((s) => s.name)` 手动缩小订阅面     | 属性级自动追踪                                               |

所以 `select` 的原理并不神秘:它把订阅包装成一个 `_SelectorSubscription`,上游变化时先跑 selector,**selector 结果不变就不通知下游**——相当于在图的边上插了一个 `distinctUntilChanged`(你熟悉 rxdart 的话,就是同一个思想)。

⚠️ `ref.read` 之所以"不响应变化",就是因为它只走值查找,**不建边**。在 `build` 里用 `read` 拿会变的状态 = 依赖图上缺了一条边,上游变化时你这个节点根本不在通知名单里。

## 四、ProviderScope:图和 Widget 树是怎么接起来的

Riverpod 的状态图**独立于 Widget 树存在**(这是它相对旧版 provider 包最大的架构差异——provider 包把状态存在 `InheritedWidget` 里,和树强绑定)。桥接靠三个角色:

```
ProviderScope (Widget)
  └── 创建并持有 ProviderContainer
  └── 通过 UncontrolledProviderScope (一个 InheritedWidget) 
      把 container 暴露给子树

ConsumerWidget / Consumer
  └── 对应的 ConsumerStatefulElement 实现了 WidgetRef
  └── build 时通过 InheritedWidget O(1) 拿到 container
  └── ref.watch → container 里对应 Element 上注册订阅
  └── 收到通知 → 调用 markNeedsBuild() → 这个 widget 重建
```

也就是说 `WidgetRef` 本质上是 `ConsumerStatefulElement` 自己——它把"Provider 图的订阅回调"翻译成 Flutter 的 `markNeedsBuild()`。这解释了两件事:

1. 为什么 `ref` 不能在 `dispose` 后使用——Element 已 unmount,订阅已撤销;
2. 为什么嵌套 `ProviderScope` 能做局部覆盖——子 Scope 创建的 container 有 `parent` 指针,未 override 的 Provider 会沿容器链向上查找,类似 iOS 里 responder chain / 环境值继承的查找语义。

## 五、autoDispose:引用计数,但不是 ARC

```dart
@riverpod  // generator 默认就是 autoDispose
Future<User> user(Ref ref) async { ... }
```

原理是**订阅者计数**:

- 每个 `watch/listen` 使计数 +1,取消订阅 -1;
- 计数归零时,Element **不会立即销毁**,而是被加入容器的待清理队列,在事件循环稍后阶段确认仍无人订阅才 dispose;
- `ref.keepAlive()` 返回一个 `KeepAliveLink`,持有它等于人为 +1。

和 ARC 的对照很有意思:

|          | Dart 对象 (GC) | autoDispose Element                   |
| -------- | -------------- | ------------------------------------- |
| 回收依据 | 可达性追踪     | 订阅者引用计数                        |
| 循环引用 | 不泄漏         | 依赖图是 DAG,不允许循环 watch(会抛错) |
| 时机     | 不确定         | 计数归零后的下一个事件循环            |

⚠️ 你之前已经踩过的坑在这里有了源码解释:**页面 push 跳转的间隙**,旧页面的 Consumer 已 deactivate、新页面还没 build,如果这瞬间计数归零,状态就被清了。Riverpod 3.x 对此做过缓解(销毁延迟到帧后确认),但跨页共享状态的正确解法仍是 `keepAlive` 或让上层某个存活的 listener 持有订阅。

## 六、Riverpod 3.x 的几个实现层变化(面试可能追问)

- **统一 Notifier 体系**:`StateNotifierProvider`/`ChangeNotifierProvider` 移入 legacy,`Notifier/AsyncNotifier/StreamNotifier` 共享同一套 Element 实现,内部状态统一用 `AsyncValue`/直接值包装。
- **自动重试**:Provider build 抛错后默认指数退避重试(可通过 `retry` 参数关闭)——这是 3.x 新增的运行时行为,升级时容易被测试暴露。
- **Ref 泛型移除**:统一为 `Ref`,`ref.state` 等旧 API 收敛,generator 生成代码更简单。
- **旁路暴露**:`Ref.mounted`、离线持久化(experimental)等。

## 七、面试速答卡

**Q: Provider 声明为全局变量,为什么不算全局状态?** A: Provider 是不可变描述(配方+作为 HashMap key 的 identity),状态存在 ProviderContainer 的 Element 里,容器可多实例、可 override,状态天然可隔离、可测试。

**Q: ref.watch 和 ref.read 的底层区别?** A: 都走值查找,但 watch 额外在目标 Element 上注册 ProviderSubscription、在依赖图上建边;read 不建边,故上游变化不会通知。

**Q: 状态变化后 UI 怎么刷新的?** A: 上游 Element 沿订阅边标 dirty → 值经 `updateShouldNotify`(或 select 的 selector)比较,不同才继续传播 → 到达 WidgetRef(即 ConsumerStatefulElement)时调 `markNeedsBuild()` 进入 Flutter 正常重建管线。

**Q: autoDispose 什么时候真正销毁?** A: 订阅计数归零后并非同步销毁,而是入队延迟确认;`keepAlive()` 通过持有 KeepAliveLink 人为维持计数。

------

想继续往下钻的话,两个自然的分支:一是用 DevTools 实测 `select` 剪枝前后的 rebuild 次数(把这套理论落到证据上);二是对照拆一遍 Bloc 的实现(`Stream` + `transformEvents`),面试里"Riverpod vs Bloc 架构差异"你就能从实现层而不是 API 层回答了。