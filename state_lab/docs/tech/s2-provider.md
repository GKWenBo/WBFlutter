# s2 · Provider：InheritedWidget 的工程化封装

> StateLab 技术文档第二篇（S2 课配套）。地基原理见 [s1-状态管理的地基](s1-状态管理的地基.md)——本文假设你已读完它。
> 实战代码：`lib/versions/v1_provider/`。

## 0. 一句话总纲

**Provider = S1 手写版 + 生命周期托管 + 粒度工具 + 更好的报错，零私有魔法。**

它没有绕开框架的任何后门：查找/依赖注册走的还是 `dependOnInheritedWidgetOfExactType` 那张 O(1) 表，通知走的还是"Element 订阅 Listenable"那条路径②。S1 你手写过全部零件——本文只回答一个问题：**多出来的那层封装，到底替你干了哪些脏活。**

## 1. 心智模型与 iOS 类比

| Provider | iOS 对应物 | 一句话 |
|---|---|---|
| `ChangeNotifierProvider(create:)` | `.environmentObject(Model())` + 系统托管生命周期 | 挂树 + create/dispose 全包 |
| `context.watch<T>()` | `@EnvironmentObject` | 取值 + 订阅（S1 的 `of()`） |
| `context.read<T>()` | 从环境拿对象调方法，不观察 | 只取值（S1 的 `read()`） |
| `context.select<T, R>()` | 观察 `@Published` 的某一个属性 | 字段级订阅 |
| `Consumer<T>` | 局部观察的 View 包装 | "of() + Builder" 官方合体 |
| `Selector<T, R>` | 同上 + 只看一个派生值 | "select + Builder" 官方合体 |
| `Provider<T>` | SwiftUI `Environment` 里放只读依赖 | 纯 DI，不监听不通知 |
| `MultiProvider` | 多个 `.environmentObject` 链式调用 | 嵌套金字塔救星（纯语法糖） |

## 2. API 全景速查表

| API | 用途 | 关键点 | 坑 |
|---|---|---|---|
| `Provider<T>` | 纯 DI（服务/配置/客户端） | 不要求 T 可监听；watch 它没意义 | 想通知就别用它，换 ChangeNotifierProvider |
| `ChangeNotifierProvider(create:)` | 新建模型并托管 | pop/卸载时**自动调 dispose**；默认 lazy（首个 read/watch 才跑 create，`lazy: false` 可关） | create 里别碰会依赖本 provider 的东西 |
| `ChangeNotifierProvider.value(value:)` | 复用已有实例（跨路由 re-provide 的官方姿势） | **不托管 dispose**——谁创建谁销毁 | 拿它新建对象 = 没人 dispose；拿 create 包已有对象 = 被二次 dispose。铁律：**新建用 create，复用用 .value** |
| `context.watch<T>()` | 取值 + 订阅 | 只能在 build/didChangeDependencies | 回调里调直接抛错（框架帮你拦，S1 讲过为什么） |
| `context.read<T>()` | 只取值 | 任何时机可调（initState/回调） | build 里滥用会"不跟新" |
| `context.select<T, R>((t) => r)` | 字段级订阅 | 通知到达后先算 selector，`==` 变了才重建 | R 是可变集合引用时 `==` 恒等 → 永不重建；每次新建集合 → 次次重建。选**标量或不可变值** |
| `Consumer<T>` | 局部订阅点 | `builder(context, model, child)`；child 参数缓存不依赖 model 的大子树 | 忘用 child，白白重建大子树 |
| `Selector<T, R>` | Consumer 的字段版 | `shouldRebuild` 默认比 `==` | 同 select 的集合坑 |
| `MultiProvider` | 多 provider 平铺 | 纯语法糖，等价嵌套 | 顺序有意义：后面的能 read 前面的 |
| `ProxyProvider<A, B>` | B 依赖 A、A 变了重造/更新 B | `update: (ctx, a, previousB) => B(a.xxx)` | MiniShop 无天然场景（YAGNI 未上工程），见 §2.1 示例 |
| `ProviderNotFoundException` | 找不到 provider 的报错 | 报错文案自带四种常见原因排查 | 最常见还是"跨路由忘 re-provide"（S1 §4.4） |

### 2.1 ProxyProvider 示例（工程里没有的那块拼图）

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => Auth()),
    // ApiClient 依赖 Auth 的 token：Auth 每次 notify，update 重新执行。
    ProxyProvider<Auth, ApiClient>(
      update: (_, auth, previous) => ApiClient(token: auth.token),
    ),
  ],
  ...
)
```

变体 `ChangeNotifierProxyProvider` 用于"被依赖方也是 ChangeNotifier 且要保实例"的场景（update 里改字段而不是新建）。什么时候需要它：对象 A 的构造/配置依赖对象 B 的**会变**的状态。MiniShop 的 ProductApi 不依赖任何会变的东西，所以不硬造（设计文档 §7 YAGNI）。

## 3. MiniShop 实战导读：S1 手写的每一行 → Provider 对应物

对照命令：`git diff <S1收官>..<S2> -- state_lab/lib/versions/`，或者直接并排开两个目录。

| S1 手写（v0_setstate） | S2 官方（v1_provider） | 帮你干了什么 |
|---|---|---|
| `V0ShopRoot` = StatefulWidget：字段建 controller、`dispose()` 里销毁、build 里挂 MiniProvider | `V1ShopRoot` = **StatelessWidget**：`MultiProvider` + `create:` | 生命周期托管——三件事变一件 |
| `MiniProvider.of<CartController>(context)` | `context.watch<CartModel>()` | 同一件事，泛型推导更顺手 |
| `MiniProvider.read<...>` | `context.read<...>` | 同一件事 |
| AppBar 里 `Builder` + `of()` 圈依赖块 | `Selector<CartModel, int>(selector: (_, c) => c.totalCount)` | **粒度从"块"进化到"字段"**：非 totalCount 变化不重建 |
| （做不到） | 详情页 `Builder` + `context.select` | 同上的函数式写法 |
| 每条 push 手动 `MiniProvider(notifier: cart, ...)` | `ChangeNotifierProvider.value(value: cart, ...)` | 同一姿势的官方名字 |
| `assert(provider != null, '这条路由包了吗?')` | `ProviderNotFoundException` + 排查建议 | 报错自带四条原因清单 |
| api 走构造函数传 | `Provider<ProductApi>` + `context.read` | **服务也走树**：页面构造函数只剩业务参数 |
| 场景①⑤状态住页面 State | `ProductListModel` / `SearchModel` + 页面级 `create:` | 状态层出 UI → 纯 Dart 单测（15 个模型测试零 pumpWidget） |

三个作用域设计（v1 的骨架）：

- **版本级**：`ProductApi`（无状态服务）、`CartModel`（跨页共享）——挂在 V1ShopRoot。
- **页面级**：`ProductListModel`、`SearchModel`——挂在各自页面头顶，**pop 即 dispose**（Timer 一起带走）。
- **页面私有**：收藏心形、TextEditingController——继续 setState/State，"一个人看的状态不上树"。

`_disposed` 守卫 = 模型侧的 `mounted`：页面 pop 触发托管 dispose,但在途请求还会回来，回来后 `notifyListeners` 会撞 "used after being disposed"。页面侧防的是 State 死了，模型侧防的是模型死了——同一个异步病，两处疫苗。

## 4. 底层原理：撕开 Provider 的封装

1. **继承链**：`ChangeNotifierProvider` → `ListenableProvider` → `InheritedProvider`。`InheritedProvider` 内部是一个定制的 InheritedWidget + 定制 Element（`_InheritedProviderScopeElement`），职责与 S1 的 `_MiniProviderElement` 一一对应：订阅 Listenable → 置脏 markNeedsBuild → build 时 notifyClients → unmount 退订。**位置相同，零件更多**（多了 lazy、DeferredStartListening、debug 检查等）。
2. **watch/read/select 落点**：`watch` → `dependOnInheritedWidgetOfExactType`（登记依赖）；`read` → `getElementForInheritedWidgetOfExactType`（拿 element 不登记）；`select` → 登记依赖时附带一个 selector 闭包，通知到达后**先跑 selector 比 `==`**，不等才 `markNeedsBuild`——这就是"字段级"的全部实现（技术上走的是 InheritedModel 式的 aspect 思路）。
3. **lazy**：`create` 默认不在挂树时执行，而在**第一次被 read/watch** 时执行（省启动开销）。v1 列表页 `create: (ctx) => ProductListModel(...)..loadFirst()` 之所以立即开载，是因为 body 的 `Consumer` 首帧就 watch 了它。如果首帧没人消费，loadFirst 会推迟——需要"挂树即创建"时传 `lazy: false`。
4. **create 的 context 能 read 上层**：create 回调拿到的是 provider 自己所在的 Element 的 context，它的父链里有根上的 `Provider<ProductApi>`——所以 `context.read<ProductApi>()` 能拿到。反过来在 create 里 read **本 provider 自己**是死循环，框架会拦。
5. **为什么 `.value` 不托管 dispose**：`.value` 的语义是"这个对象的生命周期别人在管"。托管与否是 create/.value 的**唯一**本质区别，其余行为完全一致。

## 5. 优缺点、适用场景、常见坑

**定位**：中小型 App / 以 ChangeNotifier 为中心的团队 / 从 setState 平滑升级的第一站。心智模型最接近 SwiftUI，学习曲线是几个方案里最平的。上限也明显：状态间组合/异步编排要靠 ProxyProvider 手拼，编译期无法保证 provider 一定存在（运行时才炸）——这两条正是 Riverpod 的立项理由（S6 见）。

**坑清单**（前四条 = 面试和生产事故高发区）：

1. **create/.value 用反**：`.value` 包新建对象 → 无人 dispose 泄漏；`create` 包已有对象 → 二次 dispose 崩溃。
2. **回调里 watch**：直接抛错。改 read。
3. **select/Selector 选了可变引用**：`(c) => c.items` 返回同一个 List 引用时 `==` 恒等永不重建；每次 `List.unmodifiable` 新建时 `==` 恒不等次次重建。选标量（length/totalCount）或真正不可变的值。
4. **跨路由忘 re-provide**：`ProviderNotFoundException`。读它的建议文案，四条原因挨个对。
5. **Consumer 不用 child 参数**：不依赖 model 的大子树白白陪跑。
6. **"提到 MaterialApp 之上"的取舍**（S1 思考题正式答案）：能删掉所有 `.value` re-provide 样板、所有 push 一行搞定；代价是状态生命周期 = App 生命周期（热重启才重置）、所有版本共享同一棵 provider 树（StateLab 五版本会互相污染）。单方案 App 通常提上去；本工程为版本隔离选择 re-provide。

## 6. 面试高频题（答案要点）

1. **Provider 和 InheritedWidget 什么关系？** 封装关系：InheritedProvider = 定制 InheritedWidget + 定制 Element（订阅 Listenable），外加生命周期托管、lazy、粒度 API。无私有魔法。
2. **watch / read / select 的区别？各自能在哪调？** watch=dependOn 登记依赖（build 限定）；read=拿 element 不登记（随处）；select=登记+selector 闭包比 `==`（build 限定）。回调必 read。
3. **create 和 .value 怎么选？** 新建托管用 create（自动 dispose），复用已有用 .value（不托管）。用反的两种事故要能说出来。
4. **Selector 怎么决定重不重建？** 通知到达 → 跑 selector → 新旧值 `==` → 不等才重建。集合引用的两个反例（恒等/恒不等）。
5. **Consumer 的 child 参数干嘛的？** 缓存不依赖 model 的子树，重建时原样复用（builder 第三参传回）。
6. **MultiProvider 是什么？** 纯语法糖，展开就是嵌套；顺序有意义，后者可 read 前者。
7. **ProxyProvider 什么场景？** 对象 A 依赖对象 B 的可变状态（如 ApiClient 依赖 Auth.token），B 通知时重造/更新 A。
8. **页面级 provider 的生命周期？** create 随首次消费、dispose 随 provider 卸载（页面 pop）——Timer/StreamSubscription 放模型里跟着一起走。
9. **ProviderNotFoundException 常见原因？** 跨路由没 re-provide；泛型类型没对上（`Provider<Base>` 挂树却 `watch<Sub>`）；在 provider 之上的 context 消费；lazy+heta 场景的时序问题。
10. **Provider 的上限/为什么会有 Riverpod？** 运行时才知道 provider 缺失、依赖组合靠 ProxyProvider 手拼、context 绑定导致逻辑层难以脱离 Widget 树。Riverpod 把注册表搬出树，换来编译期安全与自由组合（S6 亲手体会）。
