# Riverpod 实现原理

> **适用版本**：Riverpod 3.x / Flutter 3.x
> **前置阅读**：[Provider 实现原理](Provider实现原理.md) —— 本文的叙事起点是 Provider 的三大局限
> **配套实战**：[state_lab S6 · Riverpod 版 MiniShop](../state_lab/docs/tech/s6-riverpod.md)（API 与工程用法）
>
> ⚠️ 本文所有代码块中的"源码"均为**示意性伪代码**，用于说明机制，字段名与真实包内实现不完全一致。真实实现请对照 `riverpod` 包源码阅读。

---

## 零、一句话总纲

Provider 的三大局限——**依赖 BuildContext、按 runtimeType 查找、无编译期检查**——根源都是同一件事：**依赖图寄生在 Widget 树上**。

Riverpod 的核心动作也只有一件：**把依赖图搬出来，自建一套平行于 Element 树的运行时**。

理解了这套运行时，面试里就能从"会用 Riverpod"跃迁到"能解释它为什么这样设计"。

---

## 一、iOS 概念映射

Riverpod 同时有两个可类比的参照系，分别对应它的两重身份——**依赖注入容器**和**响应式缓存图**。

### 1.1 当它是 DI 容器：对照 Swinject

| Riverpod | Swinject / iOS 类比 | 说明 |
| --- | --- | --- |
| `Provider`（全局变量） | 注册 key / `ServiceEntry` | 只是"配方"（recipe），不持有状态 |
| `ProviderContainer` | `Container` + 一层响应式缓存 | 对象图的持有者，但带生命周期和依赖追踪 |
| `ProviderElement` | 被容器实例化后的对象 | 真正持有 state 和依赖边的运行时节点 |
| `Ref` | 注入到工厂闭包里的 `Resolver` | 但额外能建立响应式依赖 |
| `ProviderScope.overrides` | 测试时的重新注册 / mock 替换 | 编译期类型安全的替换 |
| `autoDispose` | 无直接对应，近似引用计数归零即释放 | 监听者数归零 → 销毁 state |

### 1.2 当它是响应式图：对照 SwiftUI

| Riverpod 概念 | 本质 | SwiftUI 类比 |
| --- | --- | --- |
| `Provider` | 不可变的配方 / 哈希表的键 | `EnvironmentKey`（只定义键和默认值，不存值） |
| `ProviderContainer` | 真正持有状态的容器 | `EnvironmentValues` 存储 |
| `ProviderElement` | 某 Provider 在某容器中的运行时实例 | `@StateObject` 背后的 storage |
| `Ref` | Element 对外暴露的受控句柄 | 受限的环境访问接口 |

**关键心智转换：Provider 全局变量 ≠ 全局状态。**

```dart
final counterProvider = NotifierProvider<Counter, int>(Counter.new);
```

这行全局变量常被误解为"全局单例状态"。实际上它 immutable、无状态，只是一个**身份标识 + 创建函数**。状态活在 `ProviderContainer` 内部的 `ProviderElement` 里。

由此得到关键推论：**同一个 Provider 在两个不同的 `ProviderContainer` 中，状态完全隔离**。这就是测试时 `ProviderContainer(overrides: [...])` 能工作的根基。

这与 Flutter 三树的 "Widget 是配置、Element 是实例" 完全同构，可以直接套用那套心智模型。

---

## 二、三层架构与惰性初始化

```
Provider<T>            ← "配方"，全局常量，immutable
    │  （首次被 read/watch 时）
    ▼
ProviderElement<T>     ← 运行时节点：持有 state、依赖边、监听者列表
    │  （存放于）
    ▼
ProviderContainer      ← 哈希表 {Provider → ProviderElement} + 调度器
```

容器内部逻辑的示意：

```dart
class ProviderContainer {
  // 核心存储：每个 provider 对应一个懒创建的 element
  final _elements = <ProviderBase, ProviderElement>{};

  ProviderElement _readElement(ProviderBase provider) {
    return _elements.putIfAbsent(provider, () {
      final element = provider.createElement(this);
      element.mount();   // 执行 create 函数，建立依赖边
      return element;
    });
  }

  T read<T>(ProviderListenable<T> provider) {
    final element = _readElement(provider); // 惰性：不存在才创建
    element.flush();                        // 若被标记 dirty，先重算
    return element.requireState;
  }
}
```

两个要点：

**① 惰性求值。** Element 只在第一次被 read/watch 时创建并执行 `build()`，类比 SwiftUI 的 `@Environment` 也是访问时才解析，而不是声明时。

**② 哈希表的 key 是 Provider 的 identity（内存地址）。** 这就是为什么 Provider 必须是**顶层 final 变量**——如果在 `build` 方法里动态创建 Provider，每次都是新对象、新 key，状态永远命中不了缓存。

> ⚠️ **面试高频陷阱题**：为什么 Provider 不能写在 build 里？答：identity 变了，哈希表命中不了，等于每帧新建一份状态。

对照 Provider 包：它用挂在 Element 树上的 `_inheritedElements` 哈希表做 O(1) 查找；Riverpod 直接用**容器内一张哈希表**做同样的事——所以它不需要 `BuildContext`。这就是你能在 Dio interceptor 里直接 `container.read(authTokenProvider)` 的原因。

---

## 三、依赖追踪：`ref.watch` 如何建图

这是 Riverpod 和传统 DI 容器最大的分野。Swinject 的 `resolver.resolve()` 只发生在构造时一次；Riverpod 的 `ref.watch` 在**每次 provider 重算时动态登记依赖边**。

### 3.1 建边

```dart
// 简化的 Ref.watch 逻辑
T watch<T>(ProviderBase<T> dep) {
  final depElement = container._readElement(dep);
  // 双向登记：
  _dependencies.add(depElement);      // 我依赖了它
  depElement._dependents.add(this);   // 它被我依赖（subscription）
  return depElement.state;
}
```

`ref.watch` 做两件事：**返回当前值**（内部走 read 路径）+ **注册订阅**（在被 watch 的 Element 上添加 `ProviderSubscription`，同时在自己身上记录依赖）。

多次 watch 就形成一张 **DAG（有向无环依赖图）**，节点是 ProviderElement，边由 `ref.watch` 建立：

```dart
final filteredTodos = Provider((ref) {
  final todos = ref.watch(todosProvider);   // 建边：todosProvider → filteredTodos
  final filter = ref.watch(filterProvider); // 建边：filterProvider → filteredTodos
  return todos.where(filter.apply).toList();
});
```

### 3.2 传播

```
todosProvider 状态变化
  → 遍历其 _dependents，标记下游 Element 为 dirty
  → 下游不会立即重算（除非有 listener 主动 flush）
  → 在下一次被读取 / 下一帧时，dirty Element 重新执行 build()
  → 若新值 == 旧值（updateShouldNotify，默认 identical/==），传播终止 ✂️
  → 一路走到 widget 侧的 WidgetRef 监听者 → markNeedsBuild()
```

⚠️ **两个容易被忽略的细节**：

1. **dirty 标记是惰性重算（lazy）**。上游变化只把下游标记为 dirty 并通知最末端的监听者，真正的重算发生在下一次被读取时。
2. **值对比会短路传播**。重算后若新值 `==` 旧值，传播链就此截断，下游不再 rebuild。

一句话概括：**它是缓存图，不是事件总线。**

### 3.3 动态依赖边

这是另一个面试亮点：

```dart
final contentProvider = Provider((ref) {
  final isLoggedIn = ref.watch(authProvider);
  // 依赖边是"每次执行时"动态建立的：
  return isLoggedIn
      ? ref.watch(privateFeedProvider)   // 登录时才存在这条边
      : ref.watch(publicFeedProvider);   // 未登录时才存在这条边
});
```

每次重算前，element 会清空旧依赖边重新登记（类似 SwiftUI body 每次求值重建依赖）。Swinject 做不到这件事——它没有"重算"的概念。

### 3.4 select 的剪枝原理

`select` 并不神秘：它把订阅包装成一个 selector 订阅，上游变化时先跑 selector，**selector 结果不变就不通知下游**——相当于在图的边上插了一个 `distinctUntilChanged`（熟悉 rxdart 的话，就是同一个思想）。

```dart
// 只有 user.name 变化才 rebuild，其他字段变化不触发
final name = ref.watch(userProvider.select((u) => u.name));
```

### 3.5 与 SwiftUI 的机制对照

| 机制 | Riverpod | SwiftUI |
| --- | --- | --- |
| 依赖收集方式 | **显式**：`ref.watch` 手动声明 | **隐式**：`@Observable` 的 access tracking，body 里读到哪个属性就依赖哪个 |
| 变更传播 | 沿依赖图逐层标 dirty，惰性重算，值相等则剪枝 | 依赖失效 → body 重算，diff 后决定渲染 |
| 剪枝粒度 | `select((s) => s.name)` 手动缩小订阅面 | 属性级自动追踪 |

⚠️ `ref.read` 之所以"不响应变化"，就是因为它只走值查找、**不建边**。在 `build` 里用 `read` 拿会变的状态 = 依赖图上缺了一条边，上游变化时这个节点根本不在通知名单里。

---

## 四、ProviderScope：图和 Widget 树是怎么接起来的

Riverpod 的状态图**独立于 Widget 树存在**（这是它相对 provider 包最大的架构差异——provider 包把状态存在 `InheritedWidget` 里，和树强绑定）。桥接靠三个角色：

```
ProviderScope（Widget）
  └── 创建并持有 ProviderContainer
  └── 通过 UncontrolledProviderScope（一个 InheritedWidget）
      把 container 暴露给子树

ConsumerWidget / Consumer
  └── 对应的 ConsumerStatefulElement 实现了 WidgetRef
  └── build 时通过 InheritedWidget O(1) 拿到 container
  └── ref.watch → 在 container 里对应 Element 上注册订阅
  └── 收到通知 → 调用 markNeedsBuild() → 这个 widget 重建
```

**InheritedWidget 在 Riverpod 里只剩一个职责：让 widget 找到 container，仅此而已。**

也就是说 `WidgetRef` 本质上就是 `ConsumerStatefulElement` 自己——它把"Provider 图的订阅回调"翻译成 Flutter 的 `markNeedsBuild()`。Riverpod 只负责"决定谁该刷新"，刷新本身仍是 Element 树的机制。

这解释了两件事：

1. **为什么 `ref` 不能在 `dispose` 后使用**——Element 已 unmount，订阅已撤销；
2. **为什么嵌套 `ProviderScope` 能做局部覆盖**——子 Scope 创建的 container 有 `parent` 指针，未 override 的 Provider 会沿容器链向上查找，类似 iOS 里 responder chain / 环境值继承的查找语义。

---

## 五、autoDispose：引用计数，但不是 ARC

```dart
@riverpod  // generator 默认就是 autoDispose
Future<User> user(Ref ref) async { ... }
```

原理是**监听者引用计数**——ARC 思想在状态层的复刻：

```dart
// 简化逻辑
class AutoDisposeProviderElement {
  int get _listenerCount => _dependents.length + _externalListeners.length;

  void removeListener(listener) {
    _externalListeners.remove(listener);
    if (_listenerCount == 0) {
      container._scheduleDispose(this);  // 注意：不是立即销毁
    }
  }
}
```

- 每个 `watch/listen` 使计数 +1，取消订阅 -1；
- 计数归零时 Element **不会立即销毁**，而是入队延迟确认，在事件循环稍后阶段确认仍无人订阅才 dispose；
- `ref.keepAlive()` 返回一个 `KeepAliveLink`，持有它等于人为 +1，`link.close()` 归还。

### 5.1 和 ARC / GC 的对照

| | Dart 对象（GC） | autoDispose Element |
| --- | --- | --- |
| 回收依据 | 可达性追踪 | 订阅者引用计数 |
| 循环引用 | 不泄漏 | 依赖图是 DAG，循环 watch 会抛 `CircularDependencyError` |
| 时机 | 不确定 | 计数归零后的下一个事件循环 |

### 5.2 keepAlive 的典型用法

网络请求成功后缓存结果，失败则允许销毁以便重试时重新请求：

```dart
@riverpod
Future<User> user(Ref ref) async {
  final user = await ref.watch(apiProvider).fetchUser();
  ref.keepAlive();  // 成功才缓存；抛异常则不执行，下次进入重新请求
  return user;
}
```

> 用 `riverpod_generator` 时注意：代码生成**默认就是 autoDispose**，`keepAlive: true` 才是需要显式声明的那个。

### 5.3 ⚠️ 导航间隙的状态闪断

**页面 push 跳转的间隙**，旧页面的 Consumer 已 deactivate、新页面还没 build，如果这一瞬间计数归零，状态就被清了。

延迟销毁的设计正是为了缓解这一点——页面 A → B 的瞬间，如果 B 立刻 watch 同一个 provider，state 不会丢。但跨页共享状态的**正确解法**仍是 `keepAlive()`，或让上层某个存活的 listener 持有订阅。

---

## 六、Riverpod 3.x 的实现层变化

面试报 3.x 版本时，这几点能体现你跟进了演进：

| 变化 | 说明 | 迁移风险 |
| --- | --- | --- |
| **统一 `Ref`** | 2.x 每个 provider 有专属 Ref 类型（`FutureProviderRef` 等），3.0 合并为单一 `Ref`，泛型简化，生成代码更简单 | 低，改签名即可 |
| **统一 Notifier 体系** | `StateNotifierProvider` / `ChangeNotifierProvider` 移入 legacy；`Notifier` / `AsyncNotifier` / `StreamNotifier` 共享同一套 Element 实现 | 中，需替换旧 Provider 类型 |
| **自动重试** | provider build 抛异常后默认指数退避重试，内建在 element 生命周期里，可通过 `retry` 参数关闭 | ⚠️ **高**，这是新增的运行时行为，最容易被既有测试暴露 |
| **Notifier 实例会被重建** | invalidate 后 Notifier 对象本身重新构造 | ⚠️ **高**，不要在 Notifier 上存"不属于 state 的字段" |
| **离线持久化 / mutation** | 均为 experimental，是 state 层内建副作用管理的方向 | 实验性，生产慎用 |

---

## 七、面试 Q&A 速答

**Q：Provider 声明为全局变量，不是全局状态反模式吗？**
A：全局的是**定义**（immutable 配方 + 作为哈希表 key 的 identity），状态存在 `ProviderContainer` 的 Element 里。测试时 `ProviderContainer(overrides: [...])` 新建容器即得到完全隔离的状态空间——这恰恰是可测试性的来源，等价于每个测试 new 一个 Swinject Container。

**Q：Riverpod 说自己"编译期安全"，安全在哪？**
A：三点。① Provider 是全局变量，引用它 = 引用一个确定存在的对象，不存在 provider 包那种运行时才发现树上没包的 `ProviderNotFoundException`；② 同类型多实例天然支持——两个 `Provider<String>` 是两个不同的变量身份，而 provider 包按 runtimeType 查找会冲突；③ override 是类型检查的。

**Q：`ref.watch` / `ref.listen` / `ref.read` 的底层区别？**
A：三者都走值查找，区别在订阅。`watch` 建立依赖边，值变则重算/重建且参与缓存图传播；`listen` 只注册回调（做副作用如弹 toast、导航），不触发重建；`read` 一次性取值，不建边，故上游变化不会通知。

**Q：状态变化后 UI 到底怎么刷新的？**
A：上游 Element 沿订阅边标 dirty → 值经 `updateShouldNotify`（或 select 的 selector）比较，不同才继续传播 → 到达 `WidgetRef`（即 `ConsumerStatefulElement`）时调 `markNeedsBuild()`，回归 Flutter 正常的 build 管线。Riverpod 只决定"谁该刷新"，刷新本身是 Element 树的机制。

**Q：autoDispose 什么时候真正销毁？**
A：订阅计数归零后并非同步销毁，而是入队延迟确认，在事件循环稍后阶段确认仍无人订阅才 dispose。`keepAlive()` 通过持有 `KeepAliveLink` 人为维持计数。

**Q：为什么 Provider 不能在 build 方法里创建？**
A：容器用 Provider 的 identity 作哈希表 key。build 里创建每次都是新对象、新 key，缓存永远命中不了，等于每帧新建一份状态。

---

## 八、往下钻的方向

- **落到证据上**：用 DevTools 实测 `select` 剪枝前后的 rebuild 次数，把本文的理论变成可观测数据。
- **横向对照**：拆一遍 Bloc 的实现（`Stream` + `transformEvents`），面试里"Riverpod vs Bloc 架构差异"就能从实现层而不是 API 层回答。参见 [state_lab S5 · 横向对比与选型](../state_lab/docs/tech/s5-横向对比与选型.md)。
- **测试实践**：[Flutter 测试体系](Flutter测试体系.md) 第七节，以及 [Mocktail 使用指南](Mocktail使用指南.md)。
