# S0 · 工程起步与 setState 基线版 MiniShop

> StateLab 第一课。本课交付：state_lab 工程 + 共享底座 + 首页方案列表 + **v0_setstate 完整 MiniShop**。
> 设计文档：[2026-07-11-状态管理专题课程设计.md](../2026-07-11-状态管理专题课程设计.md) · 深度技术文档从 S1 开始（本课先把"痛"体验足）。

## 一、本课重点

### 1. 五个状态场景与 v0 的原始解法

整个 StateLab 的主线是**同一个 MiniShop 用五种方案各写一遍**。需求冻结成 5 个场景，v0 用"最朴素的正确写法"逐一应对：

| # | 场景 | 在哪个页面 | v0 的解法 |
|---|---|---|---|
| ① | 异步三态 + 分页 | 商品列表 | 页面私有 `_loading/_error/_items` + setState（舒适区） |
| ② | 局部 UI 状态 | 详情页收藏心形 | 页面私有 `_favorite` + setState（舒适区，永远不该进全局） |
| ③ | 跨页共享 | 购物车（角标全页面常驻） | 根 State 持有 `List<CartItem>`，**构造函数层层下传 + 回调层层上浮** |
| ④ | 派生状态 | 合计金额/件数、角标数 | getter 现算，绝不落地存变量 |
| ⑤ | 输入流处理 | 搜索防抖 400ms | `Timer` 手搓防抖 + 请求序号丢弃过期响应 |

### 2. 核心心智模型：「共享可变引用 + 手动通知」

v0 跨页共享的本质：所有页面拿到的 `cart` 是**同一个可变 List 引用**。

- **读**：任何页面任何时刻读它都是最新值（引用相同）；
- **写**：改完之后 **Flutter 不会通知任何人**——谁的界面要刷新，谁就得被人 setState。

类比 iOS：这就像多个 VC 持有同一个 `NSMutableArray`，改完靠 delegate/notification 手动让各方 `reloadData`。Flutter 的 setState 只能重建**自己所在的子树**，于是有了下一条。

### 3. 为什么会有「双重 setState」

```
MaterialApp
 └─ Navigator
     ├─ route: VersionListPage
     ├─ route: V0ShopRoot ──build──> V0ProductListPage   ← 根 setState 管得着
     ├─ route: V0ProductDetailPage                        ← 管不着！
     └─ route: V0CartPage                                 ← 管不着！
```

detail/cart/search 是 **push 到 MaterialApp 的 Navigator 上的兄弟路由**，不在 `V0ShopRoot` 的 build 子树里。根的 setState 只能重建列表页；推出去的页面改完购物车，必须**自己再空 `setState(() {})` 一次**才能刷新自己的角标/合计。

一份状态、两处手动通知——忘掉任何一处就是「界面陈旧」bug。这是 setState 时代最常见的线上问题之一，也是 S1 InheritedWidget 出场的全部理由。

### 4. 工程骨架（为什么这么分）

- `shared/`：模型/网络/纯展示组件，**与状态管理无关**，五版共用。纯展示 Widget 只收数据和回调、禁 import 状态库（硬约束）——这样五个版本的 diff 就是纯粹的状态管理差异。
- `versions/v0_setstate/`：只有"状态层 + 页面装配"是 v0 私有的。
- `app/`：注册表 + 门禁首页（builder == null 即上锁），照搬 NativeLab 模式。

## 二、代码地图

```
state_lab/lib/
  main.dart                                  # 薄入口：runApp(StateLabApp())
  app/
    app.dart                                 # MaterialApp 装配（≈ AppDelegate+UIWindow）
    version_registry.dart                    # ShopVersion + 五版注册表（门禁）
    version_list_page.dart                   # 首页列表：解锁→push，上锁→SnackBar
  shared/
    models/product.dart                      # Product + ProductPage（手写 fromJson）
    models/cart_item.dart                    # CartItem（可变 quantity + lineTotal 派生）
    api/dio_client.dart                      # buildDio()：DummyJSON 专用 Dio 工厂
    api/product_api.dart                     # fetchProducts(skip)/searchProducts(q)
    widgets/product_card.dart                # 商品卡片（纯展示）
    widgets/async_state_view.dart            # 三态骨架：loading > error > data
    widgets/cart_icon_button.dart            # Badge.count 角标按钮
    widgets/rebuild_badge.dart               # 重建计数徽标（debug 教学道具）
  versions/v0_setstate/
    v0_shop_root.dart                        # ⭐ 状态根：_cart + 四个变更方法
    pages/product_list_page.dart             # 场景①：三态+分页；⭐痛点展品1
    pages/product_detail_page.dart           # 场景②：收藏局部态；⭐痛点展品2
    pages/cart_page.dart                     # 场景③④：共享+派生；双重 setState 全场
    pages/search_page.dart                   # 场景⑤：Timer 防抖+序号丢过期
state_lab/test/
  shared/models_test.dart                    # fromJson/hasMore/lineTotal（5 测）
  shared/product_api_test.dart               # mocktail 假 Dio 验证路径与参数（2 测）
  shared/widgets_test.dart                   # 三个纯展示件行为（3 测）
  app/version_list_page_test.dart            # 五版入口+门禁 SnackBar（1 测）
  versions/v0_cart_flow_test.dart            # 主流程：加购→角标→增减→清空（1 测）
```

## 三、控件/API 速查表（本课新面孔）

| 控件/API | iOS 类比 | 怎么用 | 易踩的坑 |
|---|---|---|---|
| `RefreshIndicator` | `UIRefreshControl` | 包住可滚动 Widget，`onRefresh` 返回 `Future`，松手转圈直到 Future 完成 | 子 Widget 必须是可滚动的；内容不满一屏时要 `AlwaysScrollableScrollPhysics` 才能下拉 |
| `NotificationListener<ScrollNotification>` | `scrollViewDidScroll` | 包住 ListView，`onNotification` 里读 `metrics.pixels / maxScrollExtent` 判断触底 | 返回 `false` 让通知继续冒泡；返回 `true` 会拦截 |
| `Dismissible` | UITableView 滑动删除（`trailingSwipeActionsConfigurationForRowAt`） | `key` 必须唯一稳定；`onDismissed` 里**必须立刻把数据删掉**，否则红屏报错 | key 用业务 id（`ValueKey(product.id)`），别用 index |
| `Badge.count` | `UITabBarItem.badgeValue` | `Badge.count(count:, isLabelVisible:, child: Icon(...))` | Material 3 组件；count 为 0 时记得 `isLabelVisible: false` |
| `Timer`（防抖） | `DispatchWorkItem.cancel` + `asyncAfter` / Combine `.debounce` | 每次输入先 `_debounce?.cancel()` 再新建 `Timer(400ms, ...)` | `dispose` 里必须 cancel，否则页面销毁后还开火 |
| 请求序号丢过期 | Combine `switchToLatest` / RxSwift `flatMapLatest` | 每发一枪 `++_requestSeq`，回来时 `seq != _requestSeq` 就扔 | 不丢过期会出现"慢请求覆盖新结果" |
| `Image.network` + `errorBuilder` | SDWebImage 的占位图 | `errorBuilder: (_, _, _) => 占位` | 测试环境的假 HttpClient 对一切请求回 400，没有 errorBuilder 测试直接红屏 |
| `Navigator.push` 手递参数 | `prepareForSegue` / init 注入 + delegate 回调 | 构造函数传数据下去、传闭包回调上来 | 本课的"痛点展品"——参数会随层级线性膨胀 |
| `mounted` | `weak self` 判空 | await 回来先 `if (!mounted) return;` 再 setState | 忘判会抛 "setState() called after dispose()" |
| `Dio` + 手写 `fromJson` | `URLSession` + 手写 `Decodable` | `dio.get(path, queryParameters:)` → `(res.data as Map)` → fromJson | JSON 数字要 `as num).toDouble()`，直接 `as double` 遇整数崩 |
| `ScaffoldMessenger` | 手写 toast/HUD | `..hideCurrentSnackBar()..showSnackBar(...)` 防叠加 | 连点会排队，先 hide 再 show 体验才对 |

## 四、v0 三大痛点清单（S1/S2 的引子）

1. **层层传参**：`_openDetail` 一次要手递 6 个参数；每加一个共享数据/操作，全链路构造函数都得改一遍（看 `product_list_page.dart` 的 ⭐ 注释）。
2. **双重 setState**：pushed 页面不在状态根子树里，一次业务变更要两处手动通知（看 `product_detail_page.dart` / `cart_page.dart` 的 ⭐ 注释）。忘一处 = 陈旧 UI bug。
3. **重建范围粗暴**：根 setState 让整个列表页子树全部重建——AppBar 上 `RebuildBadge(label: '列表角标')` 的计数就是证据：加购一件商品，整页跟着陪跑一次 build。S2 的 `Selector`、S3 的 `buildWhen`、S4 的 `Obx` 都是冲这条来的。

## 五、自测清单

1. 详情页加购后，为什么读 `widget.cart` 能拿到最新数据、但界面不自己刷新？（提示：引用 vs 通知）
2. 「双重 setState」里的两次 setState 分别刷新了谁？漏掉根那次会出什么 bug？漏掉本页那次呢？
3. 为什么合计金额用 getter 现算，而不是存一个 `_totalPrice` 变量在每次改动时更新？
4. `mounted` 判断在防什么？对应 iOS 里的什么习惯？
5. 搜索页的 `_requestSeq` 在防什么场景？如果不做会看到什么现象？
6. `RefreshIndicator.onRefresh` 为什么必须返回 `Future`？
7. `Dismissible` 的 `onDismissed` 里如果不立刻删数据会发生什么？为什么 key 不能用 index？
8. 首页列表点 v1 为什么弹 SnackBar 而不是崩溃？门禁的判断依据是什么字段？

（答案先自己写，S0 过关后我出对照版归档到 `自测答案/`。）

## 六、课后练习

给 `ProductCard` 也包一层 `RebuildBadge`（在列表页 `itemBuilder` 里包，label 用 `'卡片$index'`），然后：

1. 加购**一件**商品，观察每张卡片的计数变化——整页多少个卡片就陪跑多少次 build；
2. 思考：这些重建里哪些是必要的（角标要更新）、哪些是浪费（卡片内容根本没变）；
3. 记住这个数字——S2 的 `Selector`/`context.select` 会把它打下来，S5 会拿五个版本的计数做横向对比。

做完可以把 RebuildBadge 从卡片上撤掉（保留角标和合计栏两处），保持界面干净。
