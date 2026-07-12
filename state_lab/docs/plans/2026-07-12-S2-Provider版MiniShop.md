# S2 Provider 版 MiniShop 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `versions/v1_provider/` 完整实现 MiniShop（规格与 v0 逐像素一致），用 Provider 官方 API 逐条对照 S1 手写版——"Provider 到底帮你做了什么"；沉淀技术文档《s2-provider》。

**Architecture:** 三个 ChangeNotifier 状态层（CartModel 版本级共享、ProductListModel / SearchModel 页面级）+ 四页装配。v1 根用 `MultiProvider` 挂 `Provider<ProductApi>`（纯 DI）+ `ChangeNotifierProvider<CartModel>`；页面级模型用 `ChangeNotifierProvider(create:)` 托管 create/dispose；跨路由沿用 S1 的 re-provide 姿势但换官方 `.value`。消费端五件套用满：`context.watch`（购物车页）、`context.read`（一切回调）、`context.select`（详情页角标）、`Selector`（列表页角标）、`Consumer`（列表/搜索 body）。场景①⑤的异步状态从页面 State 搬进模型——**纯 Dart 单测直接测状态层**（v0 时代只能隔着 widget 戳），这是本课第二大红利。

**Tech Stack:** `provider ^6.1.5+1`（S0 已锁定）；新增 dev 依赖 `fake_async`（防抖单测）。

## Global Constraints

- Flutter 3.44.4 stable；每任务过关线 = `flutter analyze` 0 issue + 全量 `flutter test` 绿。
- `shared/` 纯净硬约束：v1 的状态层全部住 `lib/versions/v1_provider/state/`，纯展示 Widget 不准 import provider。
- **MiniShop 规格冻结**（设计文档第 4 节）：四页/五场景/文案与 v0 完全一致（AppBar 标题版本后缀除外：`MiniShop · v1 Provider`）。
- v0/v0.5 的任何文件**不改动**；既有 33 测中除 `test/app/version_list_page_test.dart`（门禁变化必须改）外一行不动。
- git 只 `git -C /Users/wenbo/Desktop/WBFlutter add state_lab/`，中文提交信息，一任务一提交。
- 课时讲义（Task 7）先于任何"请你验证"消息。
- 模拟器 iPhone 17 `85C08A29-994F-44BC-8BEF-C0CB6D6DBFF7`；`flutter run` 带腾讯镜像环境变量；pub 操作同样走镜像。
- 五场景归属不变：①⑤进模型（跨 build 的异步状态），②收藏心形仍页面 setState（局部态铁律），③④在 CartModel。

---

### Task 1: CartModel 状态层（TDD）+ 进度表开工

**Files:**
- Create: `state_lab/lib/versions/v1_provider/state/cart_model.dart`
- Test: `state_lab/test/versions/v1_provider/cart_model_test.dart`
- Modify: `state_lab/docs/lessons/README.md`（S2 行 → `🔄 进行中`）

**Interfaces:**
- Produces: `CartModel extends ChangeNotifier`，API 与 S1 CartController 完全同名（S5 横向对比要求）：`items/isEmpty/totalCount/totalPrice/add/changeQty/remove/clear`。
- 注：与 v0 的 CartController 蓄意重复不复用——版本自包含，任何两版 diff = 纯状态管理差异。

- [ ] **Step 1: 写失败测试**（与 S1 cart_controller_test 同构，类名换 CartModel）

```dart
// state_lab/test/versions/v1_provider/cart_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v1_provider/state/cart_model.dart';

const _p1 = Product(id: 1, title: 'A', description: 'a', price: 9.99,
    thumbnail: 'x', rating: 4.5);
const _p2 = Product(id: 2, title: 'B', description: 'b', price: 5.01,
    thumbnail: 'x', rating: 4.0);

void main() {
  group('CartModel', () {
    test('add：新商品入车；重复加购只涨数量不加行', () {
      final cart = CartModel();
      cart.add(_p1);
      cart.add(_p1);
      cart.add(_p2);
      expect(cart.items.length, 2);
      expect(cart.items.first.quantity, 2);
    });

    test('changeQty：增减数量，减到 0 自动移除', () {
      final cart = CartModel();
      cart.add(_p1);
      cart.changeQty(1, 1);
      expect(cart.items.first.quantity, 2);
      cart.changeQty(1, -2);
      expect(cart.isEmpty, isTrue);
    });

    test('remove / clear', () {
      final cart = CartModel();
      cart.add(_p1);
      cart.add(_p2);
      cart.remove(1);
      expect(cart.items.single.product.id, 2);
      cart.clear();
      expect(cart.isEmpty, isTrue);
    });

    test('派生值 totalCount / totalPrice 现算', () {
      final cart = CartModel();
      cart.add(_p1);
      cart.changeQty(1, 1); // 9.99 × 2
      cart.add(_p2); // + 5.01
      expect(cart.totalCount, 3);
      expect(cart.totalPrice, closeTo(24.99, 0.001));
    });

    test('每次变更恰好通知一次监听者', () {
      final cart = CartModel();
      var fired = 0;
      cart.addListener(() => fired++);
      cart.add(_p1);
      cart.changeQty(1, 1);
      cart.remove(1);
      cart.clear();
      expect(fired, 4);
    });

    test('items 是只读视图：外部改不动', () {
      final cart = CartModel();
      cart.add(_p1);
      expect(() => cart.items.clear(), throwsUnsupportedError);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd /Users/wenbo/Desktop/WBFlutter/state_lab && flutter test test/versions/v1_provider/cart_model_test.dart`
Expected: 编译失败（cart_model.dart 不存在）。

- [ ] **Step 3: 最小实现**

```dart
// state_lab/lib/versions/v1_provider/state/cart_model.dart
import 'package:flutter/foundation.dart';

import '../../../shared/models/cart_item.dart';
import '../../../shared/models/product.dart';

/// v1 购物车状态层。与 S1 的 CartController 一字不差——这是刻意的：
/// Provider 消费的就是普通 ChangeNotifier，状态层不用为它改一行；
/// 换掉的只是"挂树 + 取用 + 圈重建范围"那半边（对照 v0_setstate/state/）。
class CartModel extends ChangeNotifier {
  final List<CartItem> _items = [];

  /// 只读视图：想改必须走方法，方法里必发通知（S1 定下的门）。
  List<CartItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  int get totalCount => _items.fold(0, (sum, it) => sum + it.quantity);
  double get totalPrice => _items.fold(0, (sum, it) => sum + it.lineTotal);

  void add(Product product) {
    final index = _items.indexWhere((it) => it.product.id == product.id);
    if (index >= 0) {
      _items[index].quantity += 1;
    } else {
      _items.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void changeQty(int productId, int delta) {
    final index = _items.indexWhere((it) => it.product.id == productId);
    if (index < 0) return;
    _items[index].quantity += delta;
    if (_items[index].quantity <= 0) _items.removeAt(index);
    notifyListeners();
  }

  void remove(int productId) {
    _items.removeWhere((it) => it.product.id == productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/versions/v1_provider/cart_model_test.dart`
Expected: `All tests passed!`（6 测）

- [ ] **Step 5: README 进度表 S2 行改 `🔄 进行中`，提交**

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S2：CartModel 状态层（TDD 6 测）+ 进度表 S2 开工"
```

---

### Task 2: ProductListModel——场景①搬进状态层（TDD）

**Files:**
- Create: `state_lab/lib/versions/v1_provider/state/product_list_model.dart`
- Test: `state_lab/test/versions/v1_provider/product_list_model_test.dart`

**Interfaces:**
- Consumes: `shared/api/product_api.dart` 的 `ProductApi.fetchProducts({required int skip, int limit})` → `ProductPage(products/total/skip/limit/hasMore)`。
- Produces: `ProductListModel(ProductApi)`——`List<Product> get items`、`bool get loading`、`bool get loadingMore`、`String? get error`、`bool get hasMore`、`Future<void> loadFirst()`、`Future<void> loadMore()`。**`_disposed` 守卫**：dispose 后异步回来不再 notify（模型侧的 `mounted`）。

- [ ] **Step 1: 写失败测试**

```dart
// state_lab/test/versions/v1_provider/product_list_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/api/product_api.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v1_provider/state/product_list_model.dart';

const _p1 = Product(id: 1, title: 'A', description: 'a', price: 1,
    thumbnail: 'x', rating: 4);
const _p2 = Product(id: 2, title: 'B', description: 'b', price: 2,
    thumbnail: 'x', rating: 4);
const _p3 = Product(id: 3, title: 'C', description: 'c', price: 3,
    thumbnail: 'x', rating: 4);

/// 假 API：3 条数据、每页 2 条；可指定"下一次调用抛错"。
class _PagedFakeApi implements ProductApi {
  bool failNext = false;
  int fetchCalls = 0;

  @override
  Future<ProductPage> fetchProducts({
    required int skip,
    int limit = ProductApi.pageSize,
  }) async {
    fetchCalls++;
    if (failNext) {
      failNext = false;
      throw Exception('网络挂了');
    }
    const all = [_p1, _p2, _p3];
    final slice = all.skip(skip).take(2).toList();
    return ProductPage(products: slice, total: all.length, skip: skip, limit: limit);
  }

  @override
  Future<List<Product>> searchProducts(String query) =>
      throw UnimplementedError();
}

void main() {
  group('ProductListModel', () {
    test('loadFirst：loading 经历 true→false，落地第一页', () async {
      final model = ProductListModel(_PagedFakeApi());
      final loadingTrace = <bool>[];
      model.addListener(() => loadingTrace.add(model.loading));
      await model.loadFirst();
      expect(loadingTrace, [true, false]);
      expect(model.items.length, 2);
      expect(model.hasMore, isTrue);
      expect(model.error, isNull);
    });

    test('loadMore：翻页追加，到底后 hasMore=false', () async {
      final model = ProductListModel(_PagedFakeApi());
      await model.loadFirst();
      await model.loadMore();
      expect(model.items.length, 3);
      expect(model.hasMore, isFalse);
    });

    test('没有更多后 loadMore 不再发请求', () async {
      final api = _PagedFakeApi();
      final model = ProductListModel(api);
      await model.loadFirst();
      await model.loadMore();
      final calls = api.fetchCalls;
      await model.loadMore();
      expect(api.fetchCalls, calls);
    });

    test('loadFirst 失败：error 落地；重试成功后清 error', () async {
      final api = _PagedFakeApi()..failNext = true;
      final model = ProductListModel(api);
      await model.loadFirst();
      expect(model.error, contains('加载失败'));
      expect(model.items, isEmpty);
      await model.loadFirst();
      expect(model.error, isNull);
      expect(model.items.length, 2);
    });

    test('loadMore 失败不打断已有列表', () async {
      final api = _PagedFakeApi();
      final model = ProductListModel(api);
      await model.loadFirst();
      api.failNext = true;
      await model.loadMore();
      expect(model.items.length, 2); // 旧数据还在
      expect(model.error, isNull); // 静默失败，同 v0 语义
      expect(model.hasMore, isTrue); // 还能再试
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/versions/v1_provider/product_list_model_test.dart`
Expected: 编译失败。

- [ ] **Step 3: 最小实现**

```dart
// state_lab/lib/versions/v1_provider/state/product_list_model.dart
import 'package:flutter/foundation.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';

/// 场景①状态层：异步三态 + 分页，从页面 State 搬进 ChangeNotifier。
/// v0 时代这坨状态住在页面里，只能隔着 widget 测试戳；现在是纯 Dart
/// 对象——直接 new 出来断言。**可测性是搬家的最大红利**（≈ 把逻辑从
/// UIViewController 搬进 ViewModel 后终于能写单测了）。
class ProductListModel extends ChangeNotifier {
  ProductListModel(this._api);

  final ProductApi _api;

  final List<Product> _items = [];
  List<Product> get items => List.unmodifiable(_items);

  bool _loading = false;
  bool get loading => _loading;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  String? _error;
  String? get error => _error;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  int _skip = 0;

  /// 模型侧的 mounted：页面 pop 后 provider 会 dispose 本模型，
  /// 但在途的请求还会回来——回来后再 notifyListeners 就撞
  /// "used after being disposed"。守卫一下（≈ weak self 判空）。
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadFirst() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final page = await _api.fetchProducts(skip: 0);
      _items
        ..clear()
        ..addAll(page.products);
      _skip = page.products.length;
      _hasMore = page.hasMore;
      _loading = false;
      _notify();
    } catch (e) {
      _loading = false;
      _error = '加载失败：$e';
      _notify();
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return; // 防重，同 v0
    _loadingMore = true;
    _notify();
    try {
      final page = await _api.fetchProducts(skip: _skip);
      _items.addAll(page.products);
      _skip += page.products.length;
      _hasMore = page.hasMore;
    } catch (_) {
      // 加载更多失败不打断已有列表（v0 语义原样保留）
    } finally {
      _loadingMore = false;
      _notify();
    }
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/versions/v1_provider/product_list_model_test.dart`
Expected: `All tests passed!`（5 测）

- [ ] **Step 5: 提交**

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S2：ProductListModel 场景①状态层（纯 Dart 单测，TDD 5 测）"
```

---

### Task 3: SearchModel——场景⑤搬进状态层（fake_async TDD）

**Files:**
- Create: `state_lab/lib/versions/v1_provider/state/search_model.dart`
- Test: `state_lab/test/versions/v1_provider/search_model_test.dart`
- Modify: `state_lab/pubspec.yaml`（`flutter pub add dev:fake_async`）、设计文档 §6 依赖行补 `fake_async`

**Interfaces:**
- Produces: `SearchModel(ProductApi, {Duration debounce = 400ms})`——`results/loading/error/lastQuery`、`void onQueryChanged(String)`、`Future<void> retry()`。防抖 Timer 与请求序号都在模型里，页面只剩转发。

- [ ] **Step 1: 加 dev 依赖（镜像环境）**

```bash
cd /Users/wenbo/Desktop/WBFlutter/state_lab && env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy PUB_HOSTED_URL=https://mirrors.cloud.tencent.com/dart-pub FLUTTER_STORAGE_BASE_URL=https://mirrors.cloud.tencent.com/flutter flutter pub add dev:fake_async
```

- [ ] **Step 2: 写失败测试**

```dart
// state_lab/test/versions/v1_provider/search_model_test.dart
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/api/product_api.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v1_provider/state/search_model.dart';

const _p1 = Product(id: 1, title: 'phone A', description: 'a', price: 1,
    thumbnail: 'x', rating: 4);
const _p2 = Product(id: 2, title: 'phone B', description: 'b', price: 2,
    thumbnail: 'x', rating: 4);

/// 记录每次搜索词的假 API。
class _RecordingApi implements ProductApi {
  final queries = <String>[];

  @override
  Future<List<Product>> searchProducts(String query) async {
    queries.add(query);
    return const [_p1];
  }

  @override
  Future<ProductPage> fetchProducts({
    required int skip,
    int limit = ProductApi.pageSize,
  }) =>
      throw UnimplementedError();
}

/// 请求挂起、由测试手动完成的假 API——模拟"慢请求"。
class _CompleterApi implements ProductApi {
  final pending = <Completer<List<Product>>>[];

  @override
  Future<List<Product>> searchProducts(String query) {
    final completer = Completer<List<Product>>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<ProductPage> fetchProducts({
    required int skip,
    int limit = ProductApi.pageSize,
  }) =>
      throw UnimplementedError();
}

void main() {
  group('SearchModel', () {
    test('防抖：400ms 内连续输入，只发最后一枪', () {
      fakeAsync((async) {
        final api = _RecordingApi();
        final model = SearchModel(api);
        model.onQueryChanged('p');
        async.elapse(const Duration(milliseconds: 200));
        model.onQueryChanged('ph');
        async.elapse(const Duration(milliseconds: 200));
        model.onQueryChanged('phone');
        async.elapse(const Duration(milliseconds: 400));
        async.flushMicrotasks();
        expect(api.queries, ['phone']); // 前两枪被防抖掐灭
        expect(model.results.length, 1);
        expect(model.loading, isFalse);
      });
    });

    test('空查询：清空结果、不发请求', () {
      fakeAsync((async) {
        final api = _RecordingApi();
        final model = SearchModel(api);
        model.onQueryChanged('  ');
        async.elapse(const Duration(milliseconds: 400));
        async.flushMicrotasks();
        expect(api.queries, isEmpty);
        expect(model.results, isEmpty);
        expect(model.error, isNull);
      });
    });

    test('慢请求过期丢弃（手搓 switchToLatest 语义搬进模型）', () {
      fakeAsync((async) {
        final api = _CompleterApi();
        final model = SearchModel(api);
        model.onQueryChanged('ph');
        async.elapse(const Duration(milliseconds: 400)); // 第一枪已发，挂起
        model.onQueryChanged('phone');
        async.elapse(const Duration(milliseconds: 400)); // 第二枪已发，挂起
        expect(api.pending.length, 2);

        api.pending[1].complete(const [_p2]); // 新请求先回
        async.flushMicrotasks();
        expect(model.results.single.id, 2);

        api.pending[0].complete(const [_p1]); // 旧请求慢吞吞回来
        async.flushMicrotasks();
        expect(model.results.single.id, 2); // 仍是新结果：过期响应被丢
      });
    });

    test('请求失败：error 落地', () {
      fakeAsync((async) {
        final api = _CompleterApi();
        final model = SearchModel(api);
        model.onQueryChanged('phone');
        async.elapse(const Duration(milliseconds: 400));
        api.pending.single.completeError(Exception('boom'));
        async.flushMicrotasks();
        expect(model.error, contains('搜索失败'));
        expect(model.loading, isFalse);
      });
    });
  });
}
```

- [ ] **Step 3: 跑测试确认失败**

Run: `flutter test test/versions/v1_provider/search_model_test.dart`
Expected: 编译失败。

- [ ] **Step 4: 最小实现**

```dart
// state_lab/lib/versions/v1_provider/state/search_model.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';

/// 场景⑤状态层：防抖 + 序号丢过期，整个从页面搬进模型。
/// 页面瘦成"转发输入 + 展示状态"；防抖逻辑第一次变得可单测
/// （fake_async 拨表针，不用真等 400ms）。
class SearchModel extends ChangeNotifier {
  SearchModel(this._api, {this.debounce = const Duration(milliseconds: 400)});

  final ProductApi _api;

  /// 可注入的防抖时长（生产默认 400ms=设计文档冻结值；测试可调零）。
  final Duration debounce;

  Timer? _timer;
  int _requestSeq = 0;
  bool _disposed = false;

  List<Product> _results = [];
  List<Product> get results => List.unmodifiable(_results);

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  String _lastQuery = '';
  String get lastQuery => _lastQuery;

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel(); // 页面没了 Timer 还开火 = 悬垂闭包，S0 讲过
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// TextField.onChanged 直连这里：每次输入推倒重来——防抖。
  void onQueryChanged(String text) {
    _timer?.cancel();
    _timer = Timer(debounce, () => _search(text.trim()));
  }

  Future<void> retry() => _search(_lastQuery);

  Future<void> _search(String query) async {
    _lastQuery = query;
    if (query.isEmpty) {
      _results = [];
      _error = null;
      _loading = false;
      _notify();
      return;
    }
    final seq = ++_requestSeq;
    _loading = true;
    _error = null;
    _notify();
    try {
      final results = await _api.searchProducts(query);
      if (_disposed || seq != _requestSeq) return; // 过期响应，扔
      _results = results;
      _loading = false;
      _notify();
    } catch (e) {
      if (_disposed || seq != _requestSeq) return;
      _loading = false;
      _error = '搜索失败：$e';
      _notify();
    }
  }
}
```

- [ ] **Step 5: 跑测试确认通过**

Run: `flutter test test/versions/v1_provider/search_model_test.dart`
Expected: `All tests passed!`（4 测）

- [ ] **Step 6: 设计文档 §6 依赖行补 fake_async，提交**

依赖行 dev 清单追加：`fake_async ^1.3.3`（以 pub add 实际解出的版本为准）。

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S2：SearchModel 场景⑤状态层（防抖/丢过期进模型，fake_async TDD 4 测）"
```

---

### Task 4: v1 根 + 四页装配

**Files:**
- Create: `state_lab/lib/versions/v1_provider/v1_shop_root.dart`
- Create: `state_lab/lib/versions/v1_provider/pages/product_list_page.dart`
- Create: `state_lab/lib/versions/v1_provider/pages/product_detail_page.dart`
- Create: `state_lab/lib/versions/v1_provider/pages/cart_page.dart`
- Create: `state_lab/lib/versions/v1_provider/pages/search_page.dart`

**Interfaces:**
- Consumes: Task 1–3 的三个模型 + shared 全家。
- Produces: `V1ShopRoot({ProductApi? api})`（测试注入口，与 V0ShopRoot 同形）；页面签名 `V1ProductListPage()` / `V1ProductDetailPage({required Product product})` / `V1CartPage()` / `V1SearchPage()`——注意搜索页连 api 参数都没了（从树上 read）。

**消费端 API 使用地图（教学主线，写代码时对号入座）：**

| 位置 | API | 对照 S1 手写版 |
|---|---|---|
| v1 根 | `MultiProvider` + `Provider<ProductApi>` + `ChangeNotifierProvider(create:)` | Stateful 宿主 + 手动 dispose → 全部托管 |
| 列表/搜索页头 | `ChangeNotifierProvider(create: ..)..loadFirst()` | 页面级作用域：pop 即自动 dispose |
| 列表页角标 | `Selector<CartModel, int>` | Builder + of() 的强化：依赖收窄到**一个字段** |
| 详情页角标 | `Builder` + `context.select` | Selector 的函数式写法，粒度仍 = 调用它的 Element |
| 购物车页 | `context.watch<CartModel>()` | of()（页面级依赖，合理粒度） |
| 一切回调 | `context.read<T>()` | read() |
| 列表/搜索 body | `Consumer<Model>` | "of() + Builder" 官方合体 |
| 每条 push | `ChangeNotifierProvider.value` / `MultiProvider(.value)` | re-provide 同一实例 |

- [ ] **Step 1: 写 v1_shop_root.dart**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/api/dio_client.dart';
import '../../shared/api/product_api.dart';
import 'pages/product_list_page.dart';
import 'state/cart_model.dart';

/// v1 状态根。对照 S1：StatefulWidget 宿主（创建/dispose/挂树三件事）
/// 整个消失——create/dispose 由 ChangeNotifierProvider 托管，这就是
/// "Provider 帮你干的脏活"第一条。根自己瘦成 StatelessWidget。
/// Provider<ProductApi> 是纯 DI（不监听不通知）：服务对象也走树，
/// 页面连 api 构造参数都不用要了。
class V1ShopRoot extends StatelessWidget {
  const V1ShopRoot({super.key, this.api});

  /// 可注入的 API（测试传 Fake；生产走 DummyJSON）。
  final ProductApi? api;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ProductApi>(create: (_) => api ?? ProductApi(buildDio())),
        ChangeNotifierProvider<CartModel>(create: (_) => CartModel()),
      ],
      child: const V1ProductListPage(),
    );
  }
}
```

- [ ] **Step 2: 写 pages/product_list_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../../../shared/widgets/product_card.dart';
import '../../../shared/widgets/rebuild_badge.dart';
import '../state/cart_model.dart';
import '../state/product_list_model.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';
import 'search_page.dart';

/// 场景①：三态+分页——状态在 ProductListModel，页面只剩装配。
/// 对照 v0：整页 Stateless；页面级 provider 让模型生命周期 = 本页
/// 生命周期（pop 即 dispose，托管的，不用记）。
class V1ProductListPage extends StatelessWidget {
  const V1ProductListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // create 的 context 在本页之上，能 read 到根上的 ProductApi。
      // 级联 ..loadFirst()：创建即开载（≈ v0 的 initState 首载）。
      create: (context) =>
          ProductListModel(context.read<ProductApi>())..loadFirst(),
      child: const _ListScaffold(),
    );
  }
}

class _ListScaffold extends StatelessWidget {
  const _ListScaffold();

  void _openCart(BuildContext context) {
    // 跨路由 re-provide：S1 手写的那行，官方 API 叫 .value——
    // 已有实例复用用 .value，新建托管用 create（经典面试题）。
    final cart = context.read<CartModel>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: cart,
          child: const V1CartPage(),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, Product product) {
    final cart = context.read<CartModel>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: cart,
          child: V1ProductDetailPage(product: product),
        ),
      ),
    );
  }

  void _openSearch(BuildContext context) {
    // 搜索页要 api + cart 两样：MultiProvider 打包带过去。
    final cart = context.read<CartModel>();
    final api = context.read<ProductApi>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiProvider(
          providers: [
            Provider<ProductApi>.value(value: api),
            ChangeNotifierProvider<CartModel>.value(value: cart),
          ],
          child: const V1SearchPage(),
        ),
      ),
    );
  }

  bool _onScroll(BuildContext context, ScrollNotification notification) {
    if (notification.metrics.pixels >
        notification.metrics.maxScrollExtent - 200) {
      context.read<ProductListModel>().loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniShop · v1 Provider'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () => _openSearch(context),
          ),
          // Selector：S1"Builder 圈依赖"的强化版——依赖从"对象"收窄到
          // "字段"：totalCount 的值没变（==），哪怕 notifyListeners 开火
          // 也不重建。S1 只能裁块，Selector 能裁字段。
          Selector<CartModel, int>(
            selector: (_, cart) => cart.totalCount,
            builder: (context, count, _) => RebuildBadge(
              label: '列表角标',
              child: CartIconButton(
                count: count,
                onPressed: () => _openCart(context),
              ),
            ),
          ),
        ],
      ),
      // Consumer = "of() + Builder"的官方合体；第三个参数 child 用于
      // 缓存不依赖 model 的大子树（本页用不上，购物车页见对照）。
      body: Consumer<ProductListModel>(
        builder: (context, model, _) => AsyncStateView(
          loading: model.loading && model.items.isEmpty,
          error: model.items.isEmpty ? model.error : null,
          onRetry: model.loadFirst,
          builder: (_) => RefreshIndicator(
            onRefresh: model.loadFirst,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) => _onScroll(context, n),
              child: ListView.builder(
                itemCount: model.items.length + 1,
                itemBuilder: (context, index) {
                  if (index == model.items.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: model.hasMore
                            ? const CircularProgressIndicator()
                            : const Text('没有更多了'),
                      ),
                    );
                  }
                  final product = model.items[index];
                  return ProductCard(
                    product: product,
                    onTap: () => _openDetail(context, product),
                    onAddToCart: () {
                      context.read<CartModel>().add(product);
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                            const SnackBar(content: Text('已加入购物车')));
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 写 pages/product_detail_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/product.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../state/cart_model.dart';
import 'cart_page.dart';

/// 场景②：收藏心形仍是页面 setState——判断标准是"这份状态几个人看"，
/// 一个人看就留在页面，五个版本一致（S1 自测 9）。
class V1ProductDetailPage extends StatefulWidget {
  const V1ProductDetailPage({super.key, required this.product});

  final Product product;

  @override
  State<V1ProductDetailPage> createState() => _V1ProductDetailPageState();
}

class _V1ProductDetailPageState extends State<V1ProductDetailPage> {
  bool _favorite = false;

  void _openCart() {
    final cart = context.read<CartModel>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: cart,
          child: const V1CartPage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;
    return Scaffold(
      appBar: AppBar(
        title: Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: '收藏',
            icon: Icon(
              _favorite ? Icons.favorite : Icons.favorite_border,
              color: _favorite ? Colors.redAccent : null,
            ),
            onPressed: () => setState(() => _favorite = !_favorite),
          ),
          // context.select：Selector 的函数式写法。粒度仍 = 调用它的
          // Element，所以还是要用 Builder 圈住——select 不是魔法，
          // 只是"选个字段再比 =="的语法糖。
          Builder(builder: (context) {
            final count = context.select<CartModel, int>((c) => c.totalCount);
            return CartIconButton(count: count, onPressed: _openCart);
          }),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              product.thumbnail,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 220,
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.image_not_supported_outlined, size: 48),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(product.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('${product.brand ?? '无品牌'} · ⭐${product.rating}',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text('\$${product.price.toStringAsFixed(2)}',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 16),
          Text(product.description, style: theme.textTheme.bodyLarge),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton.icon(
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('加入购物车'),
            onPressed: () {
              context.read<CartModel>().add(widget.product);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('已加入购物车')));
            },
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 写 pages/cart_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/rebuild_badge.dart';
import '../state/cart_model.dart';

/// 场景③④。整页展示购物车 → context.watch 页面级依赖（与 S1 的 of()
/// 同粒度、同理由）。Stateless 从 S1 延续——"假 Stateful"退场是结构
/// 红利，不是 Provider 专属。
class V1CartPage extends StatelessWidget {
  const V1CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartModel>();
    final items = cart.items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('购物车'),
        actions: [
          TextButton(
            onPressed: cart.isEmpty ? null : cart.clear,
            child: const Text('清空'),
          ),
        ],
      ),
      body: cart.isEmpty
          ? const Center(child: Text('购物车是空的'))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Dismissible(
                  key: ValueKey(item.product.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: theme.colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => cart.remove(item.product.id),
                  child: ListTile(
                    title: Text(item.product.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle:
                        Text('\$${item.product.price.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => cart.changeQty(item.product.id, -1),
                        ),
                        Text('${item.quantity}',
                            style: theme.textTheme.titleMedium),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => cart.changeQty(item.product.id, 1),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: RebuildBadge(
                  label: '合计栏',
                  child: Row(
                    children: [
                      Text('共 ${cart.totalCount} 件',
                          style: theme.textTheme.bodyLarge),
                      const Spacer(),
                      Text(
                        '合计 \$${cart.totalPrice.toStringAsFixed(2)}',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
```

- [ ] **Step 5: 写 pages/search_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../../../shared/widgets/product_card.dart';
import '../state/cart_model.dart';
import '../state/search_model.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';

/// 场景⑤：防抖/序号都搬进了 SearchModel，页面瘦成"转发 + 展示"。
/// TextEditingController 是纯 UI 状态，留在 State（要 dispose）。
class V1SearchPage extends StatefulWidget {
  const V1SearchPage({super.key});

  @override
  State<V1SearchPage> createState() => _V1SearchPageState();
}

class _V1SearchPageState extends State<V1SearchPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openCart(BuildContext context) {
    final cart = context.read<CartModel>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: cart,
          child: const V1CartPage(),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, Product product) {
    final cart = context.read<CartModel>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: cart,
          child: V1ProductDetailPage(product: product),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // 页面级 provider：SearchModel 生命周期 = 本页（dispose 托管，
      // 里面的 Timer 也随之 cancel——对照 v0 页面手动 dispose）。
      create: (context) => SearchModel(context.read<ProductApi>()),
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '搜索商品（如 phone）',
                border: InputBorder.none,
              ),
              onChanged: context.read<SearchModel>().onQueryChanged,
            ),
            actions: [
              Selector<CartModel, int>(
                selector: (_, cart) => cart.totalCount,
                builder: (context, count, _) => CartIconButton(
                  count: count,
                  onPressed: () => _openCart(context),
                ),
              ),
            ],
          ),
          body: Consumer<SearchModel>(
            builder: (context, model, _) => model.lastQuery.isEmpty
                ? const Center(child: Text('输入关键词搜索'))
                : AsyncStateView(
                    loading: model.loading,
                    error: model.error,
                    onRetry: model.retry,
                    builder: (_) => model.results.isEmpty
                        ? const Center(child: Text('没有找到相关商品'))
                        : ListView.builder(
                            itemCount: model.results.length,
                            itemBuilder: (context, index) {
                              final product = model.results[index];
                              return ProductCard(
                                product: product,
                                onTap: () => _openDetail(context, product),
                                onAddToCart: () {
                                  context.read<CartModel>().add(product);
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(const SnackBar(
                                        content: Text('已加入购物车')));
                                },
                              );
                            },
                          ),
                  ),
          ),
        );
      }),
    );
  }
}
```

- [ ] **Step 6: 跑门禁**

Run: `flutter analyze`
Expected: `No issues found!`（此时 v1 还没上首页，但必须能编译、零告警）

- [ ] **Step 7: 提交**

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S2：v1_provider 四页装配（MultiProvider/Consumer/Selector/select/.value 全家上阵）"
```

---

### Task 5: 注册表解锁 v1 + 门禁测试更新 + v1 流程回归测试

**Files:**
- Modify: `state_lab/lib/app/version_registry.dart`（v1 接 builder）
- Modify: `state_lab/test/app/version_list_page_test.dart`（锁定断言 v1→v2）
- Test: `state_lab/test/versions/v1_cart_flow_test.dart`（新建，镜像 v0 两用例）

**Interfaces:**
- Consumes: `V1ShopRoot({ProductApi? api})`。
- Produces: 首页 v1 卡片可点进；v1 主流程 + 学员 bug 回归（与 v0 同剧本）有 widget 测试钉住。

- [ ] **Step 1: version_registry.dart——v1 条目接上 builder**

import 区加：`import '../versions/v1_provider/v1_shop_root.dart';`
v1 条目替换为（去掉 const）：

```dart
  ShopVersion(
    id: 'v1',
    title: 'v1 · Provider',
    subtitle: 'InheritedWidget 的工程化封装',
    unlockLesson: 'S2',
    builder: (_) => const V1ShopRoot(),
  ),
```

- [ ] **Step 2: 门禁测试更新**——v1 已解锁，锁定断言换 v2；补一条"v1 能推进"：

```dart
// state_lab/test/app/version_list_page_test.dart 全量替换
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/app/app.dart';

void main() {
  testWidgets('首页列出五个版本；点上锁项弹 SnackBar 提示解锁课时', (tester) async {
    await tester.pumpWidget(const StateLabApp());

    // 断言完整标题（CircleAvatar 里也有 'v0' 字样，textContaining 会命中两处）
    expect(find.text('v0 · setState 基线版'), findsOneWidget);
    expect(find.text('v1 · Provider'), findsOneWidget);
    expect(find.text('v2 · Bloc'), findsOneWidget);
    expect(find.text('v3 · GetX'), findsOneWidget);
    expect(find.text('v4 · Riverpod（结课作业）'), findsOneWidget);

    // v1 已在 S2 解锁，上锁示例换 v2
    await tester.tap(find.text('v2 · Bloc'));
    await tester.pump();
    expect(find.textContaining('S3 解锁'), findsOneWidget);
  });

  testWidgets('v1 已解锁：点卡片推进 Provider 版列表页', (tester) async {
    await tester.pumpWidget(const StateLabApp());
    await tester.tap(find.text('v1 · Provider'));
    await tester.pumpAndSettle();
    // 真实 Dio 在测试环境会秒收 400 → 页面落在错误态，但 AppBar 已是 v1
    expect(find.text('MiniShop · v1 Provider'), findsOneWidget);
  });
}
```

（若 pumpAndSettle 因 Dio 超时定时器不收敛，退化为 `await tester.pump(const Duration(milliseconds: 400));` 两次。）

- [ ] **Step 3: v1 流程测试**——剧本与 v0 两用例逐行同构（规格一致性的证明）：

```dart
// state_lab/test/versions/v1_cart_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/api/product_api.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v1_provider/v1_shop_root.dart';

const _fakeProducts = [
  Product(id: 1, title: '测试商品A', description: '描述A', price: 9.99,
      thumbnail: 'x', rating: 4.5, brand: '测试牌'),
  Product(id: 2, title: '测试商品B', description: '描述B', price: 5.01,
      thumbnail: 'x', rating: 4.0),
];

class FakeProductApi implements ProductApi {
  @override
  Future<ProductPage> fetchProducts({
    required int skip,
    int limit = ProductApi.pageSize,
  }) async {
    return ProductPage(
      products: skip == 0 ? _fakeProducts : const [],
      total: _fakeProducts.length,
      skip: skip,
      limit: limit,
    );
  }

  @override
  Future<List<Product>> searchProducts(String query) async =>
      _fakeProducts.where((p) => p.title.contains(query)).toList();
}

void main() {
  testWidgets('v1 主流程：列表加载 → 加购 → 角标 → 购物车增减/合计 → 清空', (tester) async {
    await tester.pumpWidget(MaterialApp(home: V1ShopRoot(api: FakeProductApi())));
    await tester.pump(); // create..loadFirst() 落地
    await tester.pump(); // Future 完成后的 notify 落地

    expect(find.text('测试商品A'), findsOneWidget);
    expect(find.text('测试商品B'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_shopping_cart).first);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('测试商品A'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    expect(find.text('共 2 件'), findsOneWidget);
    expect(find.textContaining('19.98'), findsOneWidget);

    await tester.tap(find.text('清空'));
    await tester.pump();
    expect(find.text('购物车是空的'), findsOneWidget);
  });

  testWidgets('S0 学员 bug 剧本在 v1 上回归：详情 → 清空 → 返回，角标清零', (tester) async {
    await tester.pumpWidget(MaterialApp(home: V1ShopRoot(api: FakeProductApi())));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('测试商品A'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('加入购物车'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空'));
    await tester.pump();
    expect(find.text('购物车是空的'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);
  });
}
```

- [ ] **Step 4: 跑门禁**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → `All tests passed!`（33 旧 + 15 新模型测 + 2 流程 + 门禁改造 ≈ 50 测上下，以实际为准）

- [ ] **Step 5: 提交**

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S2：注册表解锁 v1 + 门禁测试更新 + v1 主流程/回归测试"
```

---

### Task 6: 技术文档《s2-provider》

**Files:**
- Create: `state_lab/docs/tech/s2-provider.md`

统一六章骨架，内容要点（写作时展开为完整长文）：

1. **心智模型与 iOS 类比**：ChangeNotifierProvider+watch ≈ `.environmentObject`+`@EnvironmentObject`（这次是全托管版）；核心一句话：**Provider = S1 手写版 + 生命周期托管 + 粒度工具 + 错误提示**，零私有魔法（它就骑在 InheritedWidget 上）。
2. **API 全景速查表**：Provider（纯 DI）/ ChangeNotifierProvider（create vs `.value` 深讲）/ Consumer（child 缓存参数）/ Selector（shouldRebuild 用 `==`）/ context.watch·read·select（各自可调用时机表）/ MultiProvider（嵌套地狱救星）/ ProxyProvider 与 ChangeNotifierProxyProvider（对象间依赖，带示例：`ProxyProvider<Auth, ApiClient>(update: (_, auth, __) => ApiClient(auth.token))`——MiniShop 无天然场景不硬造，YAGNI）/ ProviderNotFoundException 读法。
3. **MiniShop 实战导读**：对照表"S1 手写的每一行 → Provider 对应物"（Task 4 的使用地图扩写）；三个模型的作用域设计（版本级 vs 页面级）；`_disposed` 守卫 ≈ 模型侧 mounted。
4. **底层原理**：Provider 的继承链（InheritedProvider → 定制 Element，与 MiniProvider 同构位置）；watch/read/select 分别落到 dependOn / getElementForInheritedWidgetOfExactType；Selector/select 的重建判定（先通知到、再比选值，`==` 不等才真重建——所以 select 返回集合时必须返回不可变快照或改用长度等标量）；lazy 默认懒创建（首个 read/watch 才跑 create，`lazy: false` 可关）；为什么 create 回调里的 context 能 read 更上层。
5. **优缺点、适用场景、常见坑**：坑清单——`.value` 误用于新建对象（dispose 没人管）/ create 误用于已有对象（被二次 dispose）/ 回调里 watch（报错文案解读）/ select 选出可变引用导致永不重建或次次重建 / 忘 MultiProvider 时的嵌套金字塔 / "provider 提到 MaterialApp 之上"的取舍（S1 思考题的正式答案：能删掉所有 .value 样板，代价是状态生命周期=App、多方案共存互染、热重启才重置）。
6. **面试高频题**（≥8 道带答案要点）：Provider 和 InheritedWidget 关系？watch/read/select 区别与可调用时机？create vs .value？Selector 怎么决定重不重建？Consumer 的 child 参数干嘛的？MultiProvider 是什么语法糖？ProxyProvider 场景？页面级 provider 的生命周期谁管？ProviderNotFoundException 常见原因（跨路由/类型没对上/在 provider 之上 read）？

- [ ] 提交：

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S2 技术文档：provider（对照手写版讲清它帮你做了什么）"
```

---

### Task 7: 课时讲义 S2（先于"请你验证"）

**Files:**
- Create: `state_lab/docs/lessons/S2-Provider版MiniShop.md`

章节要点：

1. **本课重点**：对照表"S1 手写 → Provider 对应物"；watch/read/select/Consumer/Selector 决策口诀（回调必 read；整页依赖 watch；单字段 select/Selector；要 child 缓存用 Consumer）；create vs `.value` 铁律；版本级 vs 页面级作用域；S1 思考题公布答案（提到 MaterialApp 之上：删什么、代价什么、本工程为何不采用）。
2. **代码地图**：v1_provider 树 + "与 v0.5 的 diff 就是本课全部内容"（`git diff` 命令）。
3. **控件/API 速查表**（iOS 类比 + 坑）：MultiProvider / ChangeNotifierProvider / Provider(纯DI) / Consumer / Selector / context.watch·read·select / `.value` / fake_async(测试)。
4. **关键实验**：①列表页加购看 `列表角标` RebuildBadge：v1 与 v0.5 应同为"只角标动"；②故意把详情页 `_openCart` 的 `.value` 包装删掉 → ProviderNotFoundException 红屏，读一遍它的建议文案（比 S1 手写断言更友好在哪）；③购物车页增减数量，观察 `合计栏` 计数——整页 watch 粒度下合计栏每次都动（S5 埋点：Selector 可再收窄）。
5. **自测清单**（≥8 题）：watch 在回调里调会怎样、为什么？create/.value 各自误用的后果？Selector 判定重建的依据？页面级 provider pop 时谁 dispose？`_disposed` 守卫防什么、对应页面侧什么？搜索页为什么连 api 参数都不用传了？Provider 纯 DI 和 ChangeNotifierProvider 的区别?本课哪几处依赖是"字段级"、哪几处是"页面级",为什么这么选？
6. **课后练习**：把列表页 `Selector` 临时改成页面顶层 `context.watch<CartModel>()`，加购一件观察 RebuildBadge 全页暴涨，改回来（体感"粒度即性能"）；进阶思考（带去 S3）：CartModel 的方法直接改字段+notify——如果规定"状态必须是不可变对象、每次整体替换"，会换来什么、失去什么？

- [ ] 提交：

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S2 讲义"
```

---

### Task 8: 模拟器验证与过关收尾

- [ ] **Step 1: 启动**（复用在跑的 flutter run 热重载即可；若已退出则重新拉起）：

```bash
cd /Users/wenbo/Desktop/WBFlutter/state_lab && env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
  FLUTTER_STORAGE_BASE_URL=https://mirrors.cloud.tencent.com/flutter \
  flutter run -d 85C08A29-994F-44BC-8BEF-C0CB6D6DBFF7
```

- [ ] **Step 2: 学员验证清单**：①首页 v1 卡片解锁可进；②v1 走完 v0 同款场景表（分页/刷新/加购/角标/购物车增删/合计/清空/搜索防抖）；③详情→清空→返回角标清零（老剧本新版本）；④RebuildBadge 对比实验（讲义第四节）。
- [ ] **Step 3: 学员回「确认」后**：README S2 行 → `✅ 完成（日期）`，提交 `"S2 收官：进度表翻牌"`。

---

## Self-Review 记录

- **规格覆盖**：设计文档 S2 行——ChangeNotifierProvider✓(根+页面级) / Consumer✓(列表/搜索body) / Selector✓(列表/搜索角标) / context.watch✓(购物车页)·read✓(全部回调)·select✓(详情角标) / MultiProvider✓(根+搜索push) / ProxyProvider✓(技术文档§2带示例,工程内 YAGNI 不硬造,已在计划言明) / 对照手写版✓(Task 4 使用地图+tech doc §3) / 技术文档 s2✓(Task 6)。MiniShop 四页五场景全部落地(Task 2/3/4)。
- **占位符扫描**：无 TBD；文档任务给到章节级要点与全部技术论断。
- **类型一致性**：`CartModel` API 与 S1 同名已核对；`ProductListModel.loadFirst/loadMore/items/loading/loadingMore/error/hasMore`、`SearchModel.onQueryChanged/retry/results/loading/error/lastQuery` 在 Task 2/3(定义)与 Task 4(消费)一致；`V1ShopRoot(api:)` 与测试注入一致；门禁测试改动已圈定（唯一被修改的旧测试）。
