# M5 go_router + 详情页（集中式路由）

> 本课产出：列表→详情的跳转，以及把底部 4-Tab 从"手写 IndexedStack"升级成
> go_router 的 `StatefulShellRoute` 托管。**路由集中到一张表里**（≈ Coordinator/路由中心），
> 为 M8 的"未登录拦截"和 M10 的深链留好扩展点。**go_router 是本项目唯一的导航方式，
> 后面每个页面跳转都走它。**

---

## 一、本课重点掌握（按重要程度排序）

### 1. 集中式路由表：所有页面在一处登记 ⭐⭐⭐

- go_router 把"哪个 path 对应哪个页面"集中成一张 `routes` 表（≈ iOS 的 Coordinator / 路由中心），
  而不是各页面自己 `Navigator.push(SomePage())`。
- 好处：① 一眼看全所有页面；② URL 化（能做深链）；③ 拦截逻辑（登录/权限）集中在 `redirect`（M8）。
- 本项目把路由表做成 `routerProvider`（Provider 而非顶层常量），**是为了能在 redirect 里读登录态**——
  这是 M8 鉴权拦截能成立的前提。M5 先理解"路由表是活的、能读全局状态"。

### 2. 三种跳转语义：`push` / `go` / `pushReplacement` ⭐⭐⭐

| 方法 | 栈行为 | 典型场景 | iOS 类比 |
|---|---|---|---|
| `context.push('/x')` | 在当前栈**摞一层**，能返回 | 列表→详情 | `navigationController.pushViewController` |
| `context.go('/x')` | **重算整个栈**到目标 | 登录成功切主页、切 Tab | `setViewControllers` / 换 rootVC |
| `context.pushReplacement('/x')` | **顶替**当前层 | 下单成功→订单列表（别回到结算页） | pop 当前再 push |

- 记忆钩子：**push 加一层、go 重来、pushReplacement 换脸。** 选错会导致返回栈很怪。

### 3. 路径参数 vs extra：能进 URL 的用 path，不能的用 extra ⭐⭐

```dart
GoRoute(path: '/product/:id', builder: (c, state) {
  final id = int.parse(state.pathParameters['id']!);   // 路径参数永远是 String，自己转
  return ProductDetailPage(id: id);
});
// 跳转：context.push('/product/${p.id}')
```

- **`:id` 路径参数**：适合"能放进 URL、可深链、可分享"的标识（商品 id、分类 slug）。**永远是 String，自己转 int。**
- **`state.extra`**：传"不该进 URL 的对象"（如分类展示名 `extra: c.label`）。
  坑：extra 不持久化、刷新页面/深链进来会丢，**只当"顺手带的展示数据"，别当唯一数据源**。

### 4. `StatefulShellRoute.indexedStack`：Tab 各有独立导航栈 ⭐⭐

- 升级自 M0 的手写 IndexedStack：底部 4-Tab，且**每个 Tab 拥有自己独立的导航栈**——
  在"首页" push 进详情，切到"购物车"再切回"首页"，**详情页还在**（≈ UITabBar 每个 tab 独立的 navigation stack）。
- `branches` = 各 Tab 的栈；`MainScaffold` 拿到 `navigationShell`，`goBranch(index)` 切 Tab、
  `goBranch(index, initialLocation: true)` 实现"再次点已选中 Tab 回到根"（≈ 二次点 tab 回顶）。

### 5. 顶层路由 vs shell 内路由：详情该盖住 Tab 栏 ⭐⭐

- 商品详情、登录页、搜索页是**顶层路由**（不在 shell 的 branches 里）：
  `push` 进入时**全屏盖住底部 Tab 栏**，≈ iOS `hidesBottomBarWhenPushed = true`。
- 四个 Tab 页在 shell 内（带 Tab 栏）。**"这个页面进来该不该还有底 Tab"决定它放 shell 内还是顶层。**
- 登录页尤其要放顶层：未登录被拦截时应看到一个**没有底 Tab 的全屏登录页**，而不是嵌在 Tab 框架里。

### 6. 详情页局部状态下沉：轮播图封成 `_DetailGallery` ⭐

- 详情页整体可以 `ConsumerWidget`（用 `ref.watch(productProvider(id))` 拉详情，family provider）；
  多图轮播"当前第几张"这种可变状态封进子组件 `_DetailGallery`（自己持有 PageController 并 dispose）——
  和 M1 首页把 Banner 页码封进 HomeBanner 是**同一条纪律**：状态放在最小需要它的子树。

---

## 二、新控件/API 速查表

| 概念/API | iOS 类比 | 怎么用 | 坑 |
|---|---|---|---|
| `GoRouter(routes:)` | Coordinator / 路由中心 | 集中登记 `GoRoute(path, builder)` | 做成 Provider 才能在 redirect 里读全局态（M8） |
| `MaterialApp.router` | 把导航交给路由中心 | `routerConfig: router` | 从 M0 的 `home:` 升级；两者别同时写 |
| `context.push/go/pushReplacement` | push / setVC / 替换 | 见上表 | 选错栈行为，返回按钮跳去奇怪的页 |
| `:param` 路径参数 | segue 传参 | `state.pathParameters['id']` | 永远是 String；深链能带；类型自己转 |
| `state.extra` | 传对象但不进 URL | `context.push(path, extra: obj)` | 不持久化、刷新/深链会丢，别当唯一数据源 |
| `StatefulShellRoute.indexedStack` | `UITabBarController`（各 tab 独立栈） | `branches` 定义各 Tab；`navigationShell.goBranch` 切换 | 只有放进 branch 的路由才带 Tab 栏 |
| 顶层 `GoRoute` | `hidesBottomBarWhenPushed` | 详情/登录/搜索放这里，全屏盖 Tab | 想保留 Tab 栏的页面别放顶层 |
| family provider（`productProvider(id)`） | 带参数的 ViewModel | `ref.watch(productProvider(id))` | 每个不同参数是独立实例；默认 autoDispose |

---

## 三、代码地图

```
lib/app/
  router/app_router.dart    routerProvider（Provider）：
                            _protectedPaths（M8 才用）/ redirect（M8）/ refreshListenable（M8）
                            StatefulShellRoute.indexedStack（4 Tab 各一 branch）
                            顶层路由：/product/:id、/search、/login、/favorites、/checkout、/orders、/category/:slug
  main_scaffold.dart        接 navigationShell：goBranch 切 Tab + 二次点回根
lib/features/products/presentation/
  product_detail_page.dart  ConsumerWidget + productProvider(id)；_DetailGallery 封轮播状态
  home_page.dart            商品卡 onTap: context.push('/product/${p.id}')
```

> M5 的 app_router.dart 里已经写了 `_protectedPaths`/`redirect`/`refreshListenable`，
> 但它们**要到 M8 才真正生效**（M5 时 authProvider 还没接）。这是"路由骨架先立好、
> 鉴权逻辑后填"的分工——读代码时不必纠结它们此刻拦不拦得住。

---

## 四、自测清单

1. `push` / `go` / `pushReplacement` 的栈行为各是什么？下单成功跳订单列表该用哪个？
2. 商品 id 用路径参数、分类展示名用 extra，判断标准是什么？extra 有什么坑？
3. 路由表为什么做成 `routerProvider`（Provider）而不是顶层常量？
4. 详情页和登录页为什么放顶层路由而不放 shell 的 branch 里？
5. 在"首页"push 进详情、切到别的 Tab 再切回来，详情页还在吗？为什么？
6. 路径参数 `state.pathParameters['id']` 拿到的是什么类型？

---

## 五、练习

给详情页加一个"分享"按钮，点了打印出 `/product/${id}` 这个可深链的路径——
体会"路由 URL 化"带来的能力：任何页面状态都能用一个 URL 表达（这是后面做深链、
做登录后跳回原页面的基础）。
