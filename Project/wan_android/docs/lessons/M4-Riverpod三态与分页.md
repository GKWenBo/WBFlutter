# M4 Riverpod + 三态渲染 + 分页 ⭐

> 本课产出：首页接上真实数据，用 Riverpod 管状态、`AsyncValue` 一次写清
> loading/data/error 三态，配下拉刷新 + 上拉分页。**Riverpod 是本项目的状态管理中枢，
> 从这一课起贯穿所有后续模块（购物车/收藏/鉴权/订单都是它）。这课要慢、要透。**

---

## 一、本课重点掌握（按重要程度排序）

### 1. Provider ≈ ViewModel + DI 容器，`ref` 是访问入口 ⭐⭐⭐

- Riverpod 用**代码生成**：`@riverpod` 注解 + `part 'xxx.g.dart'`，跑 build_runner 生成
  `xxxProvider`（和 M2 的 json_serializable 同一套 build_runner 工具链）。
- 三种 `ref` 用法，别混：
  - `ref.watch(p)`：**订阅**，p 一变就重建当前 Widget（≈ 订阅 `@Published`）。**放在 build 里。**
  - `ref.read(p)`：**取一次**，不订阅（≈ 一次性读值）。**放在回调/事件里**（如按钮 onTap、滚动监听）。
  - `ref.listen(p, cb)`：p 变化时跑副作用（弹 SnackBar、导航），不重建 UI。
- 记忆钩子：**build 里 watch，回调里 read。** watch 放回调会疯狂重订阅，read 放 build 拿不到更新。

### 2. `AsyncValue`：loading/data/error 三态一次写清 ⭐⭐⭐

Notifier 的 `build()` 返回 `Future`，Riverpod 自动把它包成 `AsyncValue`：

```dart
@riverpod
class ProductList extends _$ProductList {
  @override
  Future<ProductFeedState> build() async {
    final page = await ref.watch(productsRepositoryProvider).fetchProducts();
    return ProductFeedState(products: page.products,
      nextSkip: page.skip + page.products.length,
      hasMore: page.products.isNotEmpty && page.hasMore);
  }
}
```

页面订阅 `AsyncValue<ProductFeedState>`，用 `.when` 处理首屏三态。
`data` 分支读取 `feed.products`、`feed.isFromCache`、`feed.isLoadingMore` 和
`feed.appendError`；首屏加载与追加加载是不同状态，可以保留旧列表并展示分页重试。

### 3. DI 用 provider 提供依赖，测试可 override ⭐⭐⭐

```dart
final productsRepositoryProvider = Provider<ProductsRepository>(
  (ref) => ProductsRepository(dio: ref.watch(dioProvider)),
);
```

装配在 `data/products_dependencies.dart`，状态仍在 presentation/providers。
M4 的页面状态继续使用代码生成；简单装配使用普通 Provider，不需要生成另一套类型。
测试可覆盖 Repository、Cache，也可只覆盖 `dioProvider` 或 `authStorageProvider`。

### 4. 分页 = 手动合并 state，`hasMore`/`isLoadingMore` 防重入 ⭐⭐

加载更多先发布 `isLoadingMore: true`，用 `nextSkip` 请求下一页。
并发触发共享同一项 Future；成功发布合并后的状态，失败保留商品并设置 `appendError`。
空页将 `hasMore` 设为 false，避免无休止请求。

每次 `build()` 增加请求代次。分页返回后只有代次匹配且 `ref.mounted` 时才发布结果；
旧请求的 finally 也不能清掉新请求标志。这和 iOS 中用 loadID 拒绝迟到响应是同一机制。
下拉刷新仍使用 `ref.refresh(productListProvider.future)`，滚动监听仍调用 `loadMore()`。

### 5. 下拉刷新用 `ref.refresh(p.future)`；重试用 `ref.invalidate(p)` ⭐⭐

- 下拉刷新：`onRefresh: () => ref.refresh(productListProvider.future)`——
  重建 provider 重取第一页，**返回的 Future 让转圈持续到加载完成**（关键：不返回 Future 圈会秒收）。
- 错误态"重试"按钮：`ref.invalidate(productListProvider)`——让 provider 失效重建。
- 记忆钩子：`refresh` 要拿返回值（给 RefreshIndicator 等），`invalidate` 只是"作废让它重建"。

### 6. `.builder` 分页三态用 spread 拼进 slivers ⭐

- 整页是单一 `CustomScrollView`，三态各返回"一组 sliver"，用 `...asyncProducts.when(...)` spread 进去。
  这样 loading 转圈、错误提示、商品网格、底部"加载更多"footer 都在同一个滚动容器里，滚动体验统一。

---

## 二、新控件/API 速查表

| 概念/API | iOS 类比 | 怎么用 | 坑 |
|---|---|---|---|
| `@riverpod` + Notifier | ViewModel（MVVM） | `class Xxx extends _$Xxx { build() {...} }`，跑 build_runner | 改了 provider 签名要重新生成；`.g.dart` 别手改 |
| `ref.watch(p)` | 订阅 `@Published` | 放 build 里，返回当前值并订阅 | 放回调里会疯狂重订阅；watch 一个 family 记得传参数 |
| `ref.read(p)` | 一次性读值 | 放回调/事件里取一次 | 放 build 里拿不到后续更新（不订阅） |
| `ref.listen(p, cb)` | KVO/Combine sink 做副作用 | 状态变了弹窗/导航，不重建 | 副作用别写进 build（会重复触发） |
| `AsyncValue<T>` | 手写 `enum State` | `.when(loading/error/data)` 或 `.asData?.value` | `.asData?.value` 在 loading/error 时是 null，记得兜 |
| `ref.refresh(p.future)` | 手动重新请求 | 下拉刷新，`await` 它让转圈持续 | 不 `await`/不 return 这个 Future，转圈会立刻消失 |
| `ref.invalidate(p)` | 作废缓存重建 | 重试按钮 | 它不返回 Future；要等结果用 refresh |
| `state = AsyncData([...])` | 手动改数据源 reload | 分页 append、增删改 | 直接改列表内容不触发（要赋新 AsyncData，值语义） |
| `RefreshIndicator` | `UIRefreshControl` | 包住可滚动组件，`onRefresh` 返回 Future | 内容不满屏时配 `AlwaysScrollableScrollPhysics` 才拉得动 |
| `ScrollController` | `UIScrollView.contentOffset` + delegate | 监听滚动做上拉分页 | 是可变资源，`ConsumerStatefulWidget` 里持有并 `dispose` |

---

## 三、代码地图

```
lib/features/products/presentation/
  providers/products_providers.dart
    装配 provider 已迁到 data/products_dependencies.dart（可 override，M11 用）
    productProvider(id)                                  family：单商品详情（M5 详情页用）
    ProductList（Notifier）：build 首屏三态 + loadMore 分页；输出 ProductFeedState
  home_page.dart   ConsumerStatefulWidget：watch 三态 + ScrollController 上拉 +
                   RefreshIndicator 下拉 + .when spread 进 CustomScrollView
入口：main.dart 的 ProviderScope（M0 就占位了，这一课真正开始用）
```

> `isFromCache` 那一段是 M9 的离线降级伏笔（网络挂了读缓存兜底），M4 先只理解
> "build 里 try 网络、catch 兜底、都失败 rethrow"这个骨架。

---

## 四、自测清单

1. `ref.watch` / `ref.read` / `ref.listen` 各用在什么位置？watch 放回调会怎样？
2. 用了 `AsyncValue`，页面为什么不用自己维护 `isLoading` 布尔？
3. 首屏加载和"加载更多"，一个是自动一个是手动，分别体现在哪？
4. 下拉刷新为什么必须 `await`/return `ref.refresh(p.future)` 这个 Future？
5. 为什么分页元信息也要放进状态？如何防止刷新后的旧分页结果污染新列表？
6. Repository 做成 provider，给 M11 的测试带来什么便利？

---

## 五、练习

给首页加一个"空态"：当接口返回 0 条商品时，`data` 分支里判断 `feed.products.isEmpty`
显示一个"暂无商品"占位，而不是空白网格。体会 `AsyncValue.when` 的 data 分支里
仍然要处理"成功但没数据"这第四种情况（三态之外的边界）。
