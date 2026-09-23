# s4 · GetX：全局注册表上的响应式 + 一揽子全家桶

> StateLab 技术文档第四篇（S4 课配套）。地基见 [s1](s1-状态管理的地基.md)，Provider 对照见 [s2](s2-provider.md)，Bloc 对照见 [s3](s3-bloc.md)。
> 实战代码：`lib/versions/v3_getx/`。

## 0. 一句话总纲

**GetX = 一张脱离 Widget 树的全局依赖注册表（Get.put/find）+ 双轨通知（GetBuilder 手动挡 / Obx+Rx 自动挡）+ 路由/DI/工具全家桶。**

前三个方案（手写 MiniProvider、Provider、Bloc 的 BlocProvider）全都骑在 InheritedWidget 上——依赖挂在**树上**，作用域即子树，跨路由要 re-provide。GetX 掀了这张桌子：依赖住在树外的一张全局 `Map<类型+tag, 实例>` 里，任何地方 `Get.find` 直捞。于是 v1/v2 每条 push 的 `.value` 样板**全部消失**——这是它最顺手的一面；代价是依赖和生命周期都不再跟树走，编译器和树都帮不了你，纪律全靠人（§5 专节）。

## 1. 心智模型与 iOS 类比

| GetX 概念 | iOS 对应物 | 一句话 |
|---|---|---|
| `Rx<T>` / `.obs` | RxSwift 的 `BehaviorRelay` / `@Published` | 一个可订阅的值盒子，赋新值自动发流（相同值去重） |
| `Obx(() => ...)` | RxSwift 的 `bind` 到 UI | 闭包里**读了哪个 Rx 就自动订阅哪个**——隐式依赖收集 |
| `GetBuilder` + `update()` | 手动 `reloadData()` | 手动挡：普通字段随便改，改完自己喊刷新 |
| `GetxController` 生命周期 | ViewModel + viewDidLoad/deinit 钩子 | onInit / onReady / onClose |
| `Get.put` / `Get.find` | 一个全局 DI 容器（Swinject 之类） | 树外注册表，不要 context |
| workers（debounce/interval/ever/once） | RxSwift 的 debounce/throttle 算子 | 订阅 Rx 的预制算子，替手写 Timer |
| `GetMaterialApp` + `Get.to` | 全局 UINavigationController 单例 | 不要 context 的路由（本工程未用，见 §5） |

**双轨的本质区别**：自动挡（Obx）的依赖收集靠"读取时登记"——build 闭包执行时，Rx 的 getter 把当前观察者登记进自己的监听列表（和 Provider 的 `dependOn` 同一思想，只是登记表从 Element 树搬进了 Rx 对象自己）；手动挡（GetBuilder）没有任何魔法，就是 `ListNotifier.addListener` + 你手动 `update()`，等价于"把 setState 挪进 controller"。

## 2. API 全景速查表

| API | 用途 | 关键点 | 坑 |
|---|---|---|---|
| `.obs` / `RxInt/RxString/RxList...` | 造响应式值 | 赋相同值不重发（内建去重） | **RxList/RxMap 只感知增删/整项替换，元素内部字段变化必须 `refresh()`**（头号事故） |
| `Obx(() => W)` | 自动挡订阅点 | 闭包里读到的 Rx 全被订阅；粒度 = 这个 Obx | 闭包里**一个 Rx 都没读** → 直接抛 "improper use of GetX"；在回调里读 Rx 不算订阅 |
| `GetX<C>` | Obx + 自动 find controller | 少一行 Get.find | 与 Obx 二选一即可 |
| `GetBuilder<C>(id:, init:)` | 手动挡订阅点 | `init:` 托管创建 + autoRemove 销毁；`id:` 分组定向刷新 | **无参 `update()` 刷不到带 id 的 GetBuilder**（分组是隔离的，反之亦然） |
| `update([ids])` | 手动挡通知 | 改完字段自己喊；ids 点名刷新范围 | controller close 后调用会撞 → `isClosed` 守卫 |
| `Get.put<T>(obj)` | 注册即初始化 | put 时立即触发 onInit | 同类型重复 put 会顶掉旧实例 |
| `Get.lazyPut<T>(() => obj)` | 注册但延迟创建 | 首次 find 才创建（≈ Provider 的 lazy） | fenix 参数控制"删后可重生" |
| `Get.find<T>()` | 取用 | O(1) 查表，**不需要 context** | 没注册就 find → 运行时炸（编译期无保护） |
| `Get.delete<T>()` | 注销 + 触发 onClose | force: true 连 permanent 一起删 | 忘删 = 内存泄漏 + 下次进来读旧状态 |
| `Bindings` | 路由级依赖打包 | 配合 GetMaterialApp 路由自动 put/delete | 绑定 GetX 路由体系，本工程未用 |
| `GetxController` | 状态层基类 | onInit/onReady/onClose；`isClosed` 标志位 | 直接 new 不触发生命周期（测试要手动调 onInit） |
| workers `debounce/interval/ever/once` | Rx 算子 | onInit 里挂，返回 Worker | **worker 不随 controller 自动销毁**，onClose 里 `_worker.dispose()` |
| `GetxService` | 永不自动回收的服务 | 替代 permanent put | 真全局服务才用 |

## 3. MiniShop 实战导读：v1/v2 的每一行 → GetX 对应物

对照命令：`git diff <S3收官>..<S4> -- state_lab/lib/versions/`，或并排开 `v2_bloc/` 与 `v3_getx/`。

| v1 Provider / v2 Bloc | v3 GetX | 差在哪 |
|---|---|---|
| `Provider<ProductApi>` / `RepositoryProvider` | `Get.put<ProductApi>(...)` | 从树上搬进全局表 |
| `ChangeNotifierProvider(create:)` / `BlocProvider(create:)` | `Get.put` / `GetBuilder(init:)` | 前者树管生命周期；后者要么手动 delete、要么 autoRemove |
| **每条 push 的 `.value` re-provide** | **（不存在）** | 全局表不分路由——最大甜头 |
| `Consumer` / `BlocBuilder` | `Obx` / `GetBuilder(id:)` | 自动挡隐式收集 vs 手动挡点名 |
| `Selector` / `BlocSelector`（字段级） | `Obx` 本身就是最小粒度 | Obx 只重建自己；但**没有"值没变就不刷"的字段级判等**（Rx 值去重在写入端，派生值 totalCount 无此保护——items 一动角标 Obx 必刷，哪怕 count 没变） |
| `buildWhen` | `update(['id'])` 定向 | 声明式判据 vs 作者手工点名 |
| `context.read` 回调取用 | `Get.find` | 不要 context |
| v2 不可变 CartLine | **复用 shared 可变 CartItem** | GetX 回到可变世界 → refresh() 坑随之回归 |
| v1 Timer 防抖 / v2 debounce transformer | `debounce()` worker | worker 替 Timer |
| v2 restartable 丢过期 | **手写序号（v1 同款）** | GetX 没有 switchMap，这活省不掉 |
| v1 `_disposed` / v2 框架接管 | `isClosed` 手动判 | 标志位框架给，判断自己调 |

三个状态件的挡位选择（v3 骨架）：

- **`CartGetxController`（自动挡）**：跨页共享、多处订阅（两页角标 + 购物车整页）——Obx 的隐式订阅最省事。RxList 包可变 CartItem，`refresh()` 坑就在 add/changeQty 里现场演示。
- **`ProductListGetxController`（手动挡）**：单页消费、状态转移清晰——GetBuilder + `update(['list','footer'])` 定向刷新，loadingMore 翻转只惊动 footer（= buildWhen 的手工版）。
- **`SearchGetxController`（自动挡 + workers）**：输入流场景，debounce worker 上场；丢过期回到手写序号。
- 页面私有（收藏心形、TextEditingController）照旧 setState——`.obs` 能写但没必要。

## 4. 底层原理：撕开 GetX 的封装

1. **全局注册表**：`GetInstance` 内部一张 `Map<String, _InstanceBuilderFactory>`，key = 类型字符串 + tag。`Get.put` 写表并立即初始化（触发 onInit），`Get.find` 查表，`Get.delete` 删表并触发 onClose。**没有任何树参与**——这就是不要 context 的全部秘密，也是"编译器无法证明依赖存在"的根源（find 一个没注册的类型，运行时才炸）。
2. **Obx 的隐式依赖收集**：Rx 的 getter 里有一句 `RxInterface.proxy?.addListener(subject)`——build 闭包执行期间，GetX 把当前 Obx 的观察者设为全局 `proxy`，于是**读到的每个 Rx 都把自己登记给这个 Obx**。build 结束 proxy 撤下。对照：Provider 的依赖登记发生在 Element 树（`dependOn`），GetX 发生在 Rx 对象内部的监听列表——同一思想，不同宿主。这也解释了两个规则：闭包里没读 Rx 就抛错（登记表空的，Obx 永远不会刷新，GetX 直接拒绝）；回调里读 Rx 不订阅（回调执行时 proxy 早撤了）。
3. **GetBuilder/update 的朴素实现**：GetxController 混入 `ListNotifier`（一个手写的 Listenable），`update()` 通知普通监听者，`update(['id'])` 通知 id 分组监听者——**两张表是隔离的**，所以无参 update 刷不到带 id 的 GetBuilder（工程里所有通知显式带 ids 就是为了避开这个坑）。GetBuilder 的 `init:` + autoRemove 则是在自己 initState/dispose 里代调 Get.put/delete。
4. **Rx 写入端去重**：`Rx<T>` 的 setter：`if (value == newValue && !firstRebuild) return;`——相同值不发流。**注意这是写入端的去重，不是读出端的判等**：`totalCount` 这种派生 getter 没有自己的 Rx 盒子，items 一发流所有订阅它的 Obx 都会重建再现算，哪怕算出来的 count 没变。想要 v1 Selector / v2 BlocSelector 那种"值没变就不刷"，得自己把派生值也做成一个 Rx 并用 worker 同步——GetX 没有现成的字段级判等件。
5. **workers**：`debounce(rx, cb, time)` 就是"订阅 rx + 内部 Timer 重置"的预制件，返回的 `Worker` 持有那个订阅——所以 **onClose 里必须手动 `worker.dispose()`**，controller 销毁不会连带（工程里 SearchGetxController.onClose 就是示范）。

## 5. 全家桶的价值与风险边界（为什么社区有争议）

GetX 不只状态管理：路由（`Get.to/off/back`，不要 context）、DI（put/find）、SnackBar/Dialog（`Get.snackbar`）、国际化、主题……全家桶的**价值**：一个包解决一切、样板全场最少、上手飞快——小团队快速出活的利器，这是它长期霸榜 pub likes 的原因。

**风险边界**（也是争议点，逐条对应它的实现方式）：

1. **全局单例路由**：`Get.to` 依赖 `GetMaterialApp` 注册的全局 navigatorKey。绕开 context 意味着绕开了树的作用域机制——嵌套 Navigator、多 Navigator、需要局部路由的场景全都别扭。**本工程主导航不绑 GetX**（设计文档 §7）：五个版本共存于一个 MaterialApp，v3 内部也用 `Navigator.of(context).push`——GetX 状态管理和它的路由**可以拆开用**，这本身就是个重要结论。
2. **依赖关系不可见**：Provider/Bloc 的依赖挂在树上，Widget Inspector 能看、编译器能查泛型；`Get.find` 的依赖只存在于运行时的一张表里，**忘了 put、put 晚了、delete 早了都是运行时炸**。团队规模越大，这种"约定优于结构"的成本越高。
3. **生命周期与树脱钩**：没有 GetMaterialApp 的路由钩子，smart management 无从谈起——`V3ShopRoot` 手动 put/delete、搜索页手动 put/delete，忘一处就是泄漏或串味（v3 流程测试里 `tearDown(Get.reset)` 也是这个账的一部分）。
4. **魔法密度高**：Obx 的隐式依赖收集好写难查——"为什么这个 Obx 没刷新"（闭包里没读 Rx / 读的是普通字段）和"为什么它总刷新"（读了整个 RxList）都不如显式 selector 好排查。
5. **单包依赖风险**：路由+状态+DI+工具全押一个第三方包，包的维护节奏（get 4.x → 5.x 的长期 beta）直接影响整个 App 的升级路径。

**一句话立场**：GetX 的甜来自"把树绕开"，苦也来自"把树绕开"。小项目/快速原型/个人开发者用得很香；中大型团队要么立好纪律（put/delete 规范、禁用部分全家桶），要么选依赖关系显式的方案（Provider/Bloc/Riverpod）。

## 6. 面试高频题（答案要点）

1. **Obx 和 GetBuilder 的区别？** Obx 自动挡：订阅 Rx，隐式依赖收集，Rx 变了自动刷；GetBuilder 手动挡：普通字段 + 手动 update()，零 Rx 开销，可 id 分组定向刷。性能敏感、状态转移少用 GetBuilder；多处订阅、随手改用 Obx。
2. **Obx 的依赖收集怎么实现的？** build 闭包执行期间全局 `RxInterface.proxy` 指向当前观察者，Rx 的 getter 把自己登记给 proxy。所以闭包里必须**读**到至少一个 Rx，否则抛 improper use；回调里读不算订阅。
3. **RxList 改元素内部字段为什么界面不动？** RxList 只拦截增删/替换等**自身**方法，元素内部字段变化它无从感知——手动 `refresh()` 强发一次流。根治法是用不可变元素（对照 Bloc 的 CartLine）。
4. **`update()` 和 `update(['id'])`？** 前者刷所有**无 id** 的 GetBuilder，后者只刷对应 id 分组——两张监听表隔离，互相刷不到。
5. **Get.put / lazyPut / find / delete 生命周期？** put 注册即初始化（onInit）；lazyPut 首次 find 才建；delete 触发 onClose 并出表。没有 GetMaterialApp 路由钩子时全靠手动（或 GetBuilder init 的 autoRemove）。
6. **workers 有哪几个？debounce worker 要注意什么？** debounce/interval/ever/once。worker 持有 Rx 订阅，**不随 controller 自动销毁**，onClose 手动 dispose。
7. **GetX 怎么做"字段级不刷"？** 做不到开箱即用——Rx 去重在写入端，派生 getter 无判等保护。要么把派生值单独做成 Rx 手动同步，要么接受 Obx 重建（它本身粒度已很小）。
8. **不用 GetMaterialApp 能用 GetX 状态管理吗？** 能（本工程就是）：put/find/Obx/GetBuilder 全部可用；损失的是 Get.to 路由、路由绑定的 smart management、Get.snackbar 等依赖全局 navigatorKey 的能力。
9. **GetX 的争议点？** 全局单例绕开树的作用域、依赖运行时可见性差、生命周期手动管、魔法难排查、全家桶单包风险（§5 五条展开）。
10. **GetX 和 Provider/Bloc 的根本分野？** 依赖宿主：树上（InheritedWidget 系）vs 树外全局表。跨路由 re-provide 的有无、编译期/Inspector 可见性、生命周期托管方式，全部由这一条派生。
