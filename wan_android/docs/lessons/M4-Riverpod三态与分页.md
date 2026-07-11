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
  Future<List<Product>> build() async {
    final page = await ref.watch(productsRepositoryProvider).fetchProducts(...);
    return page.products;           // 请求中→loading，成功→data，抛错→error，全自动
  }
}
```

页面侧用 `.when` 把三态一次渲染，**不用自己维护 `isLoading` 布尔标志**：

```dart
ref.watch(productListProvider).when(
  loading: () => CircularProgressIndicator(),
  error:   (e, _) => ErrorView(e),
  data:    (products) => Grid(products),
);
```

- 这是 Riverpod 相比手写 ViewModel 最大的省心点：**loading/error 态是内建的，不是你手动切的**。
  iOS 里你得自己 `enum State { loading, loaded, error }` + 到处 switch，这里白送。

### 3. DI 用 provider 提供依赖，测试可 override ⭐⭐⭐

```dart
@riverpod
ProductsRepository productsRepository(Ref ref) => ProductsRepository();
```

- Repository/Cache 都做成 provider，`ProductList.build()` 里 `ref.watch(productsRepositoryProvider)` 拿。
- 好处在 M11 兑现：测试里 `ProviderScope(overrides: [productsRepositoryProvider.overrideWith(...)])`
  就能整包换成 mock——这是 M3 埋的"依赖注入"伏笔的收口。

### 4. 分页 = 手动合并 state，`hasMore`/`isLoadingMore` 防重入 ⭐⭐

```dart
Future<void> loadMore() async {
  if (_isLoadingMore || !_hasMore) return;      // 防抖 + 防越界
  final current = state.asData?.value;
  if (current == null) return;                   // 首屏还没好，先不加载
  _isLoadingMore = true;
  try {
    final page = await repo.fetchProducts(skip: current.length);  // 从已有条数续取
    _hasMore = page.hasMore;
    state = AsyncData([...current, ...page.products]);            // 手动追加合并
  } finally { _isLoadingMore = false; }
}
```

- 首屏（loading→data）是 `build()` 全自动；**"加载更多"是手动改 `state`**——把新页 append 到旧列表。
- `_isLoadingMore`（防连点重复请求）+ `_hasMore`（到底了别再请求）是分页两个必备闸门。
- 页面侧：滚动到接近底部（`pixels >= maxScrollExtent - 300`）时 `ref.read(p.notifier).loadMore()`。

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
    productsRepositoryProvider / productsCacheProvider   DI（可 override，M11 用）
    productProvider(id)                                  family：单商品详情（M5 详情页用）
    ProductList（Notifier）：build 首屏三态 + loadMore 分页 + hasMore/isFromCache
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
5. `_isLoadingMore` 和 `_hasMore` 各防的是什么问题？去掉会怎样？
6. Repository 做成 provider，给 M11 的测试带来什么便利？

---

## 五、练习

给首页加一个"空态"：当接口返回 0 条商品时，`data` 分支里判断 `products.isEmpty`
显示一个"暂无商品"占位，而不是空白网格。体会 `AsyncValue.when` 的 data 分支里
仍然要处理"成功但没数据"这第四种情况（三态之外的边界）。
