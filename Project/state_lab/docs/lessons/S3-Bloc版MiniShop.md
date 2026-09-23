# S3 · Bloc 版 MiniShop

> StateLab 第四课。本课交付：`versions/v2_bloc/` 完整 MiniShop（规格与 v0/v1 一致）+ 三个 blocTest 覆盖的状态件。
> 深度长文见 [s3-bloc](../tech/s3-bloc.md)；Provider 对照回看 [s2-provider](../tech/s2-provider.md)。

## 一、本课重点

### 1. 一句话总纲

**Bloc 把"调方法改字段 + notifyListeners"翻转成"发事件 → 纯函数 → 不可变新状态 → emit"。** 今天把 S2 自测答案练习 2 记的那笔账真金白银付一遍——多写 event/copyWith/Equatable 的样板，换回可 blocTest、可回放、可判等收窄。

对照表（本课全部内容就是把 Provider 全家换成 Bloc 全家）：

| v1 Provider | v2 Bloc | 差在哪 |
|---|---|---|
| `Provider<ProductApi>` | `RepositoryProvider<ProductApi>` | 换个惯用名，一样是纯 DI |
| `ChangeNotifierProvider(create: ..loadFirst())` | `BlocProvider(create: ..add(Started()))` | "开载"从调方法变成发事件 |
| `Consumer` | `BlocBuilder`（多了 `buildWhen`） | 整块重建可再上一道闸 |
| `Selector` / `context.select` | `BlocSelector` / `context.select` | 字段级，同 `==` 判定 |
| `context.watch`（整页） | `BlocBuilder`（整页） | 一样 |
| `notifyListeners()` + 改字段 | `emit(不可变新状态)` | 可判等/可回放，代价 copyWith |
| 手写 `Timer` 防抖 + 请求序号 | `debounce + restartable` 一个 transformer | 声明式 |
| `if (_loadingMore) return;` | `droppable()` transformer | 声明式防重入 |
| `_disposed` 守卫 | —（bloc close 后 emit 自动 no-op） | 守卫这活框架接管了 |

### 2. Cubit 还是 Bloc？（选型口诀）

- **没有事件流转换需求 → Cubit**（方法直接 emit，轻量）。购物车增删就这样 → `CartCubit`。
- **有防抖/节流/丢弃/排队 → Bloc**（`on<E>` + EventTransformer）。列表（LoadMore 要 droppable）、搜索（要 debounce+restartable）→ `ProductListBloc` / `SearchBloc`。

### 3. 不可变状态 = 今天的主角

`state/cart_state.dart` 里另起了个**不可变** `CartLine`（`Equatable` + `copyWith`），刻意不用 shared 那个可变 `CartItem`。S2 靠 `List.unmodifiable` 运行时堵门是**防御**；字段全 `final`、想改只能 `copyWith` 出新对象是**类型级根治**。交的是 copyWith 税，换回的是值语义 `==`——而 `emit(newState)` 在 `newState == state` 时**短路不重建**，正是这个 `==` 省下的。

### 4. EventTransformer：搜索页最亮的一课

v1 的搜索页手写了两坨：`Timer` 防抖 + 请求序号丢过期。v2 一个自定义 transformer 一锅端：

```dart
EventTransformer<E> _debounceRestartable<E>(Duration d) =>
    (events, mapper) => restartable<E>().call(events.debounce(d), mapper);
```

`debounce` 去抖（替 Timer），`restartable` 新事件掐掉旧处理器（switchMap，替请求序号——旧响应回来时 emit 已 no-op）。并发四选一速记：concurrent（并行）/ sequential（排队）/ droppable（忙时丢）/ restartable（新掐旧）。

### 5. 三个状态件的作用域（v2 骨架）

| 作用域 | 对象 | 挂哪 | 生命周期 |
|---|---|---|---|
| 版本级 | ProductApi、CartCubit | V2ShopRoot | 进版本建，退版本销 |
| 页面级 | ProductListBloc、SearchBloc | 各页面头顶 create | **pop 即 close** |
| 页面私有 | 收藏心形、TextEditingController | State | "一个人看的状态不上树" |

## 二、代码地图

```
state_lab/lib/versions/v2_bloc/
  v2_shop_root.dart                  # RepositoryProvider(api) + BlocProvider(CartCubit)
  state/
    cart_state.dart                  # ⭐ 不可变 CartLine(Equatable+copyWith) + CartState
    cart_cubit.dart                  # 场景③④:Cubit,方法算新状态 emit
    product_list_bloc.dart           # 场景①:Started/Refreshed/LoadMore 事件 + droppable
    search_bloc.dart                 # 场景⑤:debounce+restartable EventTransformer
  pages/
    product_list_page.dart           # BlocProvider..add(Started) / BlocSelector 角标 / BlocBuilder+buildWhen
    product_detail_page.dart         # context.select 角标;收藏仍 setState
    cart_page.dart                   # BlocBuilder 整页;清空/合计栏各自 buildWhen
    search_page.dart                 # BlocConsumer(listener 弹失败 toast + builder 展示)
state_lab/test/versions/v2_bloc/     # 14 个 blocTest(cart 5 + list 4 + search 5)
state_lab/test/versions/v2_cart_flow_test.dart  # 主流程+学员bug剧本,与 v0/v1 逐行同构
```

对照：`git diff f7218d8 HEAD -- state_lab/lib/versions/`（f7218d8 = S2 收官）。v2 与 v1 的 diff 就是本课全部内容。

## 三、控件/API 速查表（本课新面孔）

| API | iOS 类比 | 怎么用 | 易踩的坑 |
|---|---|---|---|
| `Cubit<S>` | 可订阅 ViewModel | 方法直接 `emit(新状态)` | 有事件流转换需求时不够用 |
| `Bloc<E,S>` | Subject 进 + scan 攒 + sink 出 | `on<E>(handler, transformer:)` | 忘注册 `on<E>` → 事件石沉大海 |
| `emit(newState)` | `@Published` diff | 推新状态 | `==` 相等短路——state 必须真不可变 |
| `Equatable` | Swift 值语义 struct | 重写 `props` | props 漏字段 → 该更新的界面不更新 |
| `BlocProvider(create·value)` | 同 Provider | create 新建托管 / value 复用 | 用反：泄漏 / 二次 close |
| `RepositoryProvider<T>` | Environment 放服务 | 纯 DI | 想让 UI 变？那是 Bloc 的活 |
| `BlocBuilder<B,S>` | 局部观察 | `buildWhen:(p,c)=>bool` 收窄 | 别在 builder 里做副作用 |
| `BlocSelector<B,S,R>` | 观察单个 `@Published` | 选字段比 `==` | 集合引用坑同 Selector |
| `BlocListener<B,S>` | `onReceive`/`sink(receiveValue:)` | 副作用(弹窗/导航)，`listenWhen` 收窄 | 副作用写进 builder 会重复触发 |
| `BlocConsumer<B,S>` | builder+listener 合体 | 既重建又副作用时用 | 只需其一就拆开 |
| `EventTransformer` | Combine debounce/switchToLatest | droppable/restartable/debounce | 选错并发语义 = 重复请求/过期覆盖 |
| `blocTest`(测试) | XCTest 断言状态序列 | `expect: () => [stateA, stateB]` | 用 `isA().having()` 断字段更稳 |

## 四、关键实验（模拟器上做）

1. **字段级粒度**：v2 列表页加购一件 → `列表角标` +1、商品卡不动（和 v1 一致）；`BlocSelector` 选 totalCount，值不变连 build 都不跑。
2. **整页 vs 收窄**：进购物车页增减数量，看 `合计栏` RebuildBadge——整页 `BlocBuilder` 订阅，合计栏每次都动（同 v1 watch，S5 埋点可再收窄）。
3. **防抖 + restartable**：搜索框连打 `p`→`ph`→`phone`，只发最后一枪（防抖）；快速把词改掉，旧请求的结果不会覆盖新词的结果（restartable 掐死了旧处理器）。
4. **BlocProvider 缺失体验**：临时把详情页 `_openCart` 的 `BlocProvider.value` 删掉 → 点购物车红屏，读 `BlocProvider.of() called with a context that does not contain a CartCubit` 的建议文案。改回来。
5. 常规场景表照走：分页/刷新/购物车增删/合计/详情清空返回。

## 五、自测清单

1. Cubit 和 Bloc 怎么选？MiniShop 三个状态件各选了哪个、为什么？
2. `emit` 一个和当前值相等的 state 会怎样？这和 `Equatable` 什么关系？
3. `buildWhen` 返回 false 时发生什么？它和 `BlocSelector` 是什么关系？
4. 为什么防抖要放 EventTransformer，而不在 TextField 里 setState 计时？
5. `droppable` 和 `restartable` 分别替掉了 v1 的哪行手写代码？
6. 不可变 `CartLine` 相比可变 `CartItem` 多写了什么、换回了什么？state 里塞可变字段会出什么 bug？
7. `RepositoryProvider` 和 `BlocProvider` 区别？前者对应 Provider 里的什么？
8. `BlocListener` 相比 `BlocBuilder` 什么时候用？副作用写进 builder 会怎样？
9. v1 的 `_disposed` 守卫在 v2 去哪了？为什么可以不写？
10. 不可变状态换来的三样红利、付出的三样代价，分别是什么？（练习 2 的正式答案）

（答案先自己写，过关后归档 `自测答案/`。）

## 六、课后练习

1. **并发模型即正确性**：把 `product_list_bloc.dart` 里 `ProductListLoadMore` 的 `droppable()` 改成 `concurrent()`，模拟器上快速触底两次，观察 `fetchCalls` 翻倍、列表重复追加；改回 `droppable`。体会"并发语义选错 = 正确性 bug"。
2. **过期覆盖复现**：把 `search_bloc.dart` 的 `restartable` 换成 `sequential`，快速改词（趁上一枪慢请求没回来），观察旧词的结果覆盖了新词——这就是 v1 用请求序号防的那个 bug。改回来。
3. **进阶思考（带去 S4 GetX）**：Bloc 强制"事件→状态"的仪式感换来纪律，但样板也是几个方案里最多的。如果有个方案让你既能 `.obs` 一把梭（像 setState 那样随手改），又能在需要时上结构、还顺手把路由和依赖注入全给你——你会怎么权衡这份"便利 vs 约束"？S4 见。
