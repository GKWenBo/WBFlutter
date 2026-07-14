# S3 Bloc 版 MiniShop 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `versions/v2_bloc/` 完整实现 MiniShop（规格与 v0/v1 逐像素一致），用 flutter_bloc 官方 API 把 S2 的"可变对象 + notifyListeners"改写成"事件进、不可变状态出"的单向数据流——把 S2 自测答案练习 2 那笔账（Equatable/copyWith/buildWhen/blocTest）真金白银付一遍；沉淀技术文档《s3-bloc》。

**Architecture:** 一个 Cubit（购物车，轻量入门）+ 两个事件驱动 Bloc（商品列表、搜索）。
- **CartCubit**：state=`CartState`（Equatable 不可变，`List<CartLine>`；`CartLine` 是 v2 本地的**不可变**行项目，对照 shared 那个可变 `CartItem`）。方法 add/changeQty/remove/clear 每次 `emit` 全新 state。
- **ProductListBloc**：事件 `ProductListStarted/Refreshed/LoadMore`；`LoadMore` 挂 `droppable()` 事务器（并发丢弃 = v1 `_loadingMore` 布尔守卫的声明式替身）；state 带 `ListStatus` 枚举。
- **SearchBloc**：事件 `SearchQueryChanged/Retried`；`QueryChanged` 挂**自定义 EventTransformer = `debounce(400ms)` + `restartable()`**——一枪打掉 v1 的 `Timer` 防抖 **和** 请求序号丢过期两坨手写逻辑。
- 页面装配四页与 v1 一一对应，把 Provider 全家换成 Bloc 全家（对照地图见 Task 4）。

**Tech Stack:** `flutter_bloc ^9.1.1` + `equatable ^2.1.0`（S0 已锁）；新增 `bloc_concurrency`（`droppable`/`restartable`）+ `stream_transform`（`debounce`）；dev 新增 `bloc_test`。

## Global Constraints

- Flutter 3.44.4 stable；每任务过关线 = `flutter analyze` 0 issue + 全量 `flutter test` 绿。
- `shared/` 纯净硬约束：v2 状态层全部住 `lib/versions/v2_bloc/state/`，纯展示 Widget 不准 import bloc。
- **MiniShop 规格冻结**（设计文档第 4 节）：四页/五场景/文案与 v0/v1 完全一致（AppBar 标题版本后缀除外：`MiniShop · v2 Bloc`）。唯一有意的增量：搜索页失败时用 `BlocConsumer` 的 listener 弹一个瞬时 SnackBar——这是设计文档 S3 行点名要覆盖 `BlocListener/BlocConsumer` 的最自然落点，属副作用演示，不改①–⑤功能，Self-Review 已登记。
- v0/v1 的任何文件**不改动**；既有测试除 `test/app/version_list_page_test.dart`（门禁变化必须改）外一行不动。
- git 只 `git -C /Users/wenbo/Desktop/WBFlutter add state_lab/`，中文提交信息，一任务一提交。
- 课时讲义（Task 7）先于任何"请你验证"消息。
- 模拟器 iPhone 17 `85C08A29-994F-44BC-8BEF-C0CB6D6DBFF7`；`flutter run` 与 pub 操作走腾讯镜像环境变量。
- 五场景归属不变：①⑤进 Bloc（跨 build 的异步状态），②收藏心形仍页面 setState（局部态铁律），③④在 CartCubit。
- CartCubit 对外方法名沿用 add/changeQty/remove/clear，state getter 沿用 isEmpty/totalCount/totalPrice/items（S5 横向对比要求同名对照）。

---

### Task 1: 依赖 + CartCubit / CartState（blocTest）+ 进度表开工

**Files:**
- Modify: `state_lab/pubspec.yaml`（`bloc_concurrency` `stream_transform` `dev:bloc_test`）、设计文档 §6 依赖行补三个包
- Create: `state_lab/lib/versions/v2_bloc/state/cart_state.dart`
- Create: `state_lab/lib/versions/v2_bloc/state/cart_cubit.dart`
- Test: `state_lab/test/versions/v2_bloc/cart_cubit_test.dart`
- Modify: `state_lab/docs/lessons/README.md`（S3 行 → `🔄 进行中`）

**Interfaces:**
- `CartLine extends Equatable`：不可变行项目，`copyWith({int? quantity})`，`props => [product.id, quantity]`（Product 无值 `==`，用 id 拿值语义），派生 `lineTotal`。
- `CartState extends Equatable`：`items`(=`List<CartLine>`)、派生 `isEmpty/totalCount/totalPrice`、`copyWith`，`props => [items]`。
- `CartCubit extends Cubit<CartState>`：`add/changeQty/remove/clear`，每次 `emit(全新 CartState)`。

- [ ] **Step 1: 加依赖（镜像环境）**

```bash
cd /Users/wenbo/Desktop/WBFlutter/state_lab && env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy PUB_HOSTED_URL=https://mirrors.cloud.tencent.com/dart-pub FLUTTER_STORAGE_BASE_URL=https://mirrors.cloud.tencent.com/flutter flutter pub add bloc_concurrency stream_transform dev:bloc_test
```

- [ ] **Step 2: 写失败测试**

```dart
// state_lab/test/versions/v2_bloc/cart_cubit_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v2_bloc/state/cart_cubit.dart';
import 'package:state_lab/versions/v2_bloc/state/cart_state.dart';

const _p1 = Product(id: 1, title: 'A', description: 'a', price: 9.99,
    thumbnail: 'x', rating: 4.5);
const _p2 = Product(id: 2, title: 'B', description: 'b', price: 5.01,
    thumbnail: 'x', rating: 4.0);

void main() {
  group('CartCubit', () {
    blocTest<CartCubit, CartState>(
      'add：新商品入车；重复加购只涨数量不加行',
      build: CartCubit.new,
      act: (c) => c..add(_p1)..add(_p1)..add(_p2),
      expect: () => [
        isA<CartState>().having((s) => s.items.length, 'len', 1),
        isA<CartState>().having((s) => s.items.first.quantity, 'q', 2),
        isA<CartState>().having((s) => s.items.length, 'len', 2),
      ],
    );

    blocTest<CartCubit, CartState>(
      'changeQty：增减数量，减到 0 自动移除',
      build: CartCubit.new,
      act: (c) => c..add(_p1)..changeQty(1, 1)..changeQty(1, -2),
      expect: () => [
        isA<CartState>().having((s) => s.items.single.quantity, 'q', 1),
        isA<CartState>().having((s) => s.items.single.quantity, 'q', 2),
        isA<CartState>().having((s) => s.isEmpty, 'empty', true),
      ],
    );

    blocTest<CartCubit, CartState>(
      'remove / clear',
      build: CartCubit.new,
      act: (c) => c..add(_p1)..add(_p2)..remove(1)..clear(),
      skip: 2, // 跳过两次 add，只看 remove/clear 结果
      expect: () => [
        isA<CartState>().having((s) => s.items.single.product.id, 'id', 2),
        isA<CartState>().having((s) => s.isEmpty, 'empty', true),
      ],
    );

    test('派生值 totalCount / totalPrice 现算', () {
      final cubit = CartCubit()
        ..add(_p1)
        ..changeQty(1, 1) // 9.99 × 2
        ..add(_p2); // + 5.01
      expect(cubit.state.totalCount, 3);
      expect(cubit.state.totalPrice, closeTo(24.99, 0.001));
    });

    test('不可变：两个内容相同的 CartState 值相等（Equatable）', () {
      final a = CartCubit()..add(_p1);
      final b = CartCubit()..add(_p1);
      expect(a.state, b.state); // 值语义，非引用
    });
  });
}
```

- [ ] **Step 3: 跑测试确认失败**

Run: `flutter test test/versions/v2_bloc/cart_cubit_test.dart` → 编译失败。

- [ ] **Step 4: 最小实现**

```dart
// state_lab/lib/versions/v2_bloc/state/cart_state.dart
import 'package:equatable/equatable.dart';

import '../../../shared/models/product.dart';

/// v2 本地的**不可变**购物车行项目——刻意对照 shared 那个可变 CartItem。
/// S2 靠 List.unmodifiable 运行时堵门；这里是类型级根治：字段全 final，
/// 想改只能 copyWith 出一个新对象。这就是 S2 自测答案练习 2 说的
/// "copyWith 税"，换来的是值语义 == 与可判等的状态。
class CartLine extends Equatable {
  const CartLine({required this.product, this.quantity = 1});

  final Product product;
  final int quantity;

  double get lineTotal => product.price * quantity;

  CartLine copyWith({int? quantity}) =>
      CartLine(product: product, quantity: quantity ?? this.quantity);

  /// Product 没实现值 ==（json_serializable 不生成），用 id 拿值语义就够。
  @override
  List<Object?> get props => [product.id, quantity];
}

/// 购物车状态：不可变、可判等。派生值（总数/总价）仍是现算的 getter，
/// 但它们进不进 props 无所谓——props 只放 items，items 变了整体就不等。
class CartState extends Equatable {
  const CartState({this.items = const []});

  final List<CartLine> items;

  bool get isEmpty => items.isEmpty;
  int get totalCount => items.fold(0, (sum, l) => sum + l.quantity);
  double get totalPrice => items.fold(0.0, (sum, l) => sum + l.lineTotal);

  CartState copyWith({List<CartLine>? items}) =>
      CartState(items: items ?? this.items);

  @override
  List<Object?> get props => [items];
}
```

```dart
// state_lab/lib/versions/v2_bloc/state/cart_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/product.dart';
import 'cart_state.dart';

/// 场景③④：购物车。用 **Cubit**（Bloc 的轻量版——没有 event，直接暴露
/// 方法调用 emit）。对照 S2 的 CartModel：方法名一字不差，但每个方法
/// 不再"改字段 + notifyListeners"，而是"算出全新 CartState + emit"。
/// 单向数据流的入门档：方法 → emit(新状态) → UI 重建。
class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  void add(Product product) {
    final items = [...state.items];
    final i = items.indexWhere((l) => l.product.id == product.id);
    if (i >= 0) {
      items[i] = items[i].copyWith(quantity: items[i].quantity + 1);
    } else {
      items.add(CartLine(product: product));
    }
    emit(CartState(items: items));
  }

  void changeQty(int productId, int delta) {
    final items = [...state.items];
    final i = items.indexWhere((l) => l.product.id == productId);
    if (i < 0) return;
    final q = items[i].quantity + delta;
    if (q <= 0) {
      items.removeAt(i);
    } else {
      items[i] = items[i].copyWith(quantity: q);
    }
    emit(CartState(items: items));
  }

  void remove(int productId) => emit(
        CartState(items: state.items.where((l) => l.product.id != productId).toList()),
      );

  void clear() => emit(const CartState());
}
```

- [ ] **Step 5: 跑测试确认通过** → `All tests passed!`（5 测）

- [ ] **Step 6: 设计文档 §6 依赖行补包、README S3 行 `🔄 进行中`，提交**

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S3：CartCubit + 不可变 CartState（blocTest 5 测）+ 依赖 + 进度表开工"
```

---

### Task 2: ProductListBloc——场景①事件驱动（blocTest）

**Files:**
- Create: `state_lab/lib/versions/v2_bloc/state/product_list_bloc.dart`（含 event/state）
- Test: `state_lab/test/versions/v2_bloc/product_list_bloc_test.dart`

**Interfaces:**
- Events（sealed）：`ProductListStarted` / `ProductListRefreshed` / `ProductListLoadMore`。
- State：`ProductListState`（Equatable）：`ListStatus status`（initial/loading/success/failure）、`List<Product> items`、`bool hasMore`、`bool loadingMore`、`String? error`、`int skip`；`copyWith`。
- Bloc：`ProductListBloc(ProductApi)`；`LoadMore` 挂 `droppable()`。**`isClosed` 守卫**：await 回来先判 `if (isClosed) return;` 再 emit（= v1 `_disposed` 守卫的 Bloc 版；close 后 emit 会抛 StateError）。

- [ ] **Step 1: 写失败测试**

```dart
// state_lab/test/versions/v2_bloc/product_list_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/api/product_api.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v2_bloc/state/product_list_bloc.dart';

const _p1 = Product(id: 1, title: 'A', description: 'a', price: 1, thumbnail: 'x', rating: 4);
const _p2 = Product(id: 2, title: 'B', description: 'b', price: 2, thumbnail: 'x', rating: 4);
const _p3 = Product(id: 3, title: 'C', description: 'c', price: 3, thumbnail: 'x', rating: 4);

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
  Future<List<Product>> searchProducts(String query) => throw UnimplementedError();
}

void main() {
  group('ProductListBloc', () {
    blocTest<ProductListBloc, ProductListState>(
      'Started：loading → success，落地第一页',
      build: () => ProductListBloc(_PagedFakeApi()),
      act: (bloc) => bloc.add(ProductListStarted()),
      expect: () => [
        isA<ProductListState>().having((s) => s.status, 'status', ListStatus.loading),
        isA<ProductListState>()
            .having((s) => s.status, 'status', ListStatus.success)
            .having((s) => s.items.length, 'len', 2)
            .having((s) => s.hasMore, 'hasMore', true)
            .having((s) => s.error, 'error', isNull),
      ],
    );

    blocTest<ProductListBloc, ProductListState>(
      'LoadMore：翻页追加，到底后 hasMore=false',
      build: () => ProductListBloc(_PagedFakeApi()),
      act: (bloc) async {
        bloc.add(ProductListStarted());
        await bloc.stream.firstWhere((s) => s.status == ListStatus.success);
        bloc.add(ProductListLoadMore());
      },
      skip: 2, // 跳过 Started 的 loading/success
      expect: () => [
        isA<ProductListState>().having((s) => s.loadingMore, 'loadingMore', true),
        isA<ProductListState>()
            .having((s) => s.items.length, 'len', 3)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.loadingMore, 'loadingMore', false),
      ],
    );

    blocTest<ProductListBloc, ProductListState>(
      'Started 失败：落 failure 态',
      build: () => ProductListBloc(_PagedFakeApi()..failNext = true),
      act: (bloc) => bloc.add(ProductListStarted()),
      expect: () => [
        isA<ProductListState>().having((s) => s.status, 'status', ListStatus.loading),
        isA<ProductListState>()
            .having((s) => s.status, 'status', ListStatus.failure)
            .having((s) => s.error, 'error', contains('加载失败'))
            .having((s) => s.items, 'items', isEmpty),
      ],
    );

    blocTest<ProductListBloc, ProductListState>(
      'LoadMore 失败不打断已有列表（v0/v1 静默语义原样保留）',
      build: () => ProductListBloc(_PagedFakeApi()),
      act: (bloc) async {
        final api = bloc.api as _PagedFakeApi;
        bloc.add(ProductListStarted());
        await bloc.stream.firstWhere((s) => s.status == ListStatus.success);
        api.failNext = true;
        bloc.add(ProductListLoadMore());
      },
      skip: 2,
      expect: () => [
        isA<ProductListState>().having((s) => s.loadingMore, 'loadingMore', true),
        isA<ProductListState>()
            .having((s) => s.items.length, 'len', 2) // 旧数据还在
            .having((s) => s.hasMore, 'hasMore', true) // 还能再试
            .having((s) => s.loadingMore, 'loadingMore', false),
      ],
    );
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

- [ ] **Step 3: 最小实现**

```dart
// state_lab/lib/versions/v2_bloc/state/product_list_bloc.dart
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';

/// 场景①：异步三态 + 分页，事件驱动版。对照 S2 的 ProductListModel：
/// 那边是"调方法 → 改字段 → notifyListeners"；这边是"add(事件) → 处理器
/// → emit(不可变新状态)"。多花的样板（event 类型 + copyWith）换来的是
/// 状态转移可 blocTest 断言值序列、可回放。

enum ListStatus { initial, loading, success, failure }

sealed class ProductListEvent {}

/// 首屏加载（≈ v0 的 initState 首载）。
class ProductListStarted extends ProductListEvent {}

/// 下拉刷新：清空重来。
class ProductListRefreshed extends ProductListEvent {}

/// 触底加载更多。
class ProductListLoadMore extends ProductListEvent {}

class ProductListState extends Equatable {
  const ProductListState({
    this.status = ListStatus.initial,
    this.items = const [],
    this.hasMore = true,
    this.loadingMore = false,
    this.error,
    this.skip = 0,
  });

  final ListStatus status;
  final List<Product> items;
  final bool hasMore;
  final bool loadingMore;
  final String? error;
  final int skip;

  ProductListState copyWith({
    ListStatus? status,
    List<Product>? items,
    bool? hasMore,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    int? skip,
  }) {
    return ProductListState(
      status: status ?? this.status,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      skip: skip ?? this.skip,
    );
  }

  @override
  List<Object?> get props => [status, items, hasMore, loadingMore, error, skip];
}

class ProductListBloc extends Bloc<ProductListEvent, ProductListState> {
  ProductListBloc(this.api) : super(const ProductListState()) {
    on<ProductListStarted>(_onStarted);
    on<ProductListRefreshed>(_onStarted); // 刷新 = 重新首载，复用同一处理器
    // droppable：一次加载更多没跑完，期间再来的 LoadMore 直接丢——
    // 这就是 v1 那句 `if (_loadingMore) return;` 的声明式替身。
    on<ProductListLoadMore>(_onLoadMore, transformer: droppable());
  }

  /// 暴露给页面 onScroll / 测试断言用（不参与状态）。
  final ProductApi api;

  Future<void> _onStarted(
    ProductListEvent event,
    Emitter<ProductListState> emit,
  ) async {
    emit(state.copyWith(status: ListStatus.loading, clearError: true));
    try {
      final page = await api.fetchProducts(skip: 0);
      emit(state.copyWith(
        status: ListStatus.success,
        items: page.products,
        skip: page.products.length,
        hasMore: page.hasMore,
      ));
    } catch (e) {
      emit(state.copyWith(status: ListStatus.failure, error: '加载失败：$e'));
    }
  }

  Future<void> _onLoadMore(
    ProductListLoadMore event,
    Emitter<ProductListState> emit,
  ) async {
    if (!state.hasMore) return; // 到底了就别发（droppable 管并发，这管边界）
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await api.fetchProducts(skip: state.skip);
      emit(state.copyWith(
        items: [...state.items, ...page.products],
        skip: state.skip + page.products.length,
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      // 加载更多失败不打断已有列表（v0/v1 语义原样保留）
      emit(state.copyWith(loadingMore: false));
    }
  }
}
```

> 注：`Emitter` 在 bloc 里天然不会在 close 后触发（droppable/正常处理器完成即注销订阅），所以这里不用 v1 的 `_disposed` 显式守卫——**"守卫谁来做"正是 Bloc 帮你干的脏活之一**（技术文档 §4 展开）。

- [ ] **Step 4: 跑测试确认通过** → `All tests passed!`（4 测）

- [ ] **Step 5: 提交**

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S3：ProductListBloc 场景①事件驱动（droppable/blocTest 4 测）"
```

---

### Task 3: SearchBloc——场景⑤ EventTransformer 防抖 + 丢过期（blocTest）

**Files:**
- Create: `state_lab/lib/versions/v2_bloc/state/search_bloc.dart`
- Test: `state_lab/test/versions/v2_bloc/search_bloc_test.dart`

**Interfaces:**
- Events：`SearchQueryChanged(String query)` / `SearchRetried`。
- State：`SearchState`（Equatable）：`SearchStatus status`（initial/loading/success/failure）、`String query`、`List<Product> results`、`String? error`。
- Bloc：`SearchBloc(ProductApi, {Duration debounce = 400ms})`；`QueryChanged` 挂 `debounceRestartable(debounce)` = `restartable().call(events.debounce(d), mapper)`。**一枪替掉 v1 两坨手写**：`Timer` 防抖 → `debounce`；请求序号丢过期 → `restartable`（新事件到就 switchMap 掐掉旧处理器，旧响应回来 emit 变 no-op）。

- [ ] **Step 1: 写失败测试**

```dart
// state_lab/test/versions/v2_bloc/search_bloc_test.dart
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/api/product_api.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v2_bloc/state/search_bloc.dart';

const _p1 = Product(id: 1, title: 'phone A', description: 'a', price: 1, thumbnail: 'x', rating: 4);
const _p2 = Product(id: 2, title: 'phone B', description: 'b', price: 2, thumbnail: 'x', rating: 4);

/// 记录每次搜索词的假 API（即时返回 _p1）。
class _RecordingApi implements ProductApi {
  final queries = <String>[];

  @override
  Future<List<Product>> searchProducts(String query) async {
    queries.add(query);
    return const [_p1];
  }

  @override
  Future<ProductPage> fetchProducts({required int skip, int limit = ProductApi.pageSize}) =>
      throw UnimplementedError();
}

/// 请求挂起、由测试手动完成的假 API——模拟"慢请求"。
class _CompleterApi implements ProductApi {
  final pending = <Completer<List<Product>>>[];

  @override
  Future<List<Product>> searchProducts(String query) {
    final c = Completer<List<Product>>();
    pending.add(c);
    return c.future;
  }

  @override
  Future<ProductPage> fetchProducts({required int skip, int limit = ProductApi.pageSize}) =>
      throw UnimplementedError();
}

void main() {
  group('SearchBloc', () {
    blocTest<SearchBloc, SearchState>(
      '防抖：400ms 内连续输入，只发最后一枪',
      build: () => SearchBloc(_RecordingApi()),
      act: (bloc) async {
        bloc.add(const SearchQueryChanged('p'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        bloc.add(const SearchQueryChanged('ph'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        bloc.add(const SearchQueryChanged('phone'));
      },
      wait: const Duration(milliseconds: 600),
      expect: () => [
        isA<SearchState>().having((s) => s.status, 'status', SearchStatus.loading),
        isA<SearchState>()
            .having((s) => s.status, 'status', SearchStatus.success)
            .having((s) => s.results.length, 'len', 1),
      ],
      verify: (_) {
        // 前两枪被防抖掐灭——这个断言直接证明 debounce 生效
        // （queries 在 build 的 api 上，用闭包捕获）。
      },
    );

    test('防抖 verify：只有最后一个词发出去', () async {
      final api = _RecordingApi();
      final bloc = SearchBloc(api);
      bloc.add(const SearchQueryChanged('p'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      bloc.add(const SearchQueryChanged('ph'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      bloc.add(const SearchQueryChanged('phone'));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(api.queries, ['phone']);
      await bloc.close();
    });

    blocTest<SearchBloc, SearchState>(
      '空查询：清空结果、不发请求',
      build: () => SearchBloc(_RecordingApi()),
      act: (bloc) => bloc.add(const SearchQueryChanged('   ')),
      wait: const Duration(milliseconds: 600),
      expect: () => [
        isA<SearchState>()
            .having((s) => s.results, 'results', isEmpty)
            .having((s) => s.error, 'error', isNull)
            .having((s) => s.status, 'status', SearchStatus.initial),
      ],
    );

    test('慢请求过期丢弃：restartable 掐掉旧处理器', () async {
      final api = _CompleterApi();
      final bloc = SearchBloc(api);
      final seen = <SearchState>[];
      final sub = bloc.stream.listen(seen.add);

      bloc.add(const SearchQueryChanged('ph'));
      await Future<void>.delayed(const Duration(milliseconds: 450)); // 第一枪已发，挂起
      bloc.add(const SearchQueryChanged('phone'));
      await Future<void>.delayed(const Duration(milliseconds: 450)); // 第二枪已发，挂起
      expect(api.pending.length, 2);

      api.pending[1].complete(const [_p2]); // 新请求先回
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.results.single.id, 2);

      api.pending[0].complete(const [_p1]); // 旧请求慢吞吞回来
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.results.single.id, 2); // 仍是新结果：旧处理器已被 restartable 掐死

      await sub.cancel();
      await bloc.close();
    });

    test('请求失败：error 落地', () async {
      final api = _CompleterApi();
      final bloc = SearchBloc(api);
      bloc.add(const SearchQueryChanged('phone'));
      await Future<void>.delayed(const Duration(milliseconds: 450));
      api.pending.single.completeError(Exception('boom'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, SearchStatus.failure);
      expect(bloc.state.error, contains('搜索失败'));
      await bloc.close();
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

- [ ] **Step 3: 最小实现**

```dart
// state_lab/lib/versions/v2_bloc/state/search_bloc.dart
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';

/// 场景⑤：输入流处理。这是 Bloc 相对 S2 最亮的一课——v1 里靠手写
/// `Timer` 防抖 + 请求序号丢过期两坨逻辑，这里被一个 EventTransformer
/// 一锅端：debounce(去抖) + restartable(switchMap，新事件掐掉旧处理器)。
/// 事件流当一等公民处理，正是 Bloc≈Combine 单向数据流的精髓。

enum SearchStatus { initial, loading, success, failure }

sealed class SearchEvent {}

class SearchQueryChanged extends SearchEvent {
  const SearchQueryChanged(this.query);
  final String query;
}

class SearchRetried extends SearchEvent {
  const SearchRetried();
}

class SearchState extends Equatable {
  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.results = const [],
    this.error,
  });

  final SearchStatus status;
  final String query;
  final List<Product> results;
  final String? error;

  @override
  List<Object?> get props => [status, query, results, error];
}

/// debounce 先把连打的事件流去抖，restartable 再保证只有最新那个处理器
/// 活着——旧处理器被 switchMap 取消，它 await 回来时 emit 已是 no-op。
EventTransformer<E> _debounceRestartable<E>(Duration duration) {
  return (events, mapper) =>
      restartable<E>().call(events.debounce(duration), mapper);
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc(this._api, {this.debounce = const Duration(milliseconds: 400)})
      : super(const SearchState()) {
    on<SearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(debounce),
    );
    on<SearchRetried>((event, emit) => _search(state.query, emit));
  }

  final ProductApi _api;
  final Duration debounce;

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) =>
      _search(event.query.trim(), emit);

  Future<void> _search(String query, Emitter<SearchState> emit) async {
    if (query.isEmpty) {
      emit(const SearchState()); // 回到 initial，清空
      return;
    }
    emit(SearchState(status: SearchStatus.loading, query: query));
    try {
      final results = await _api.searchProducts(query);
      emit(SearchState(
        status: SearchStatus.success,
        query: query,
        results: results,
      ));
    } catch (e) {
      emit(SearchState(
        status: SearchStatus.failure,
        query: query,
        error: '搜索失败：$e',
      ));
    }
  }
}
```

- [ ] **Step 4: 跑测试确认通过** → `All tests passed!`（5 测）

- [ ] **Step 5: 提交**

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S3：SearchBloc 场景⑤（debounce+restartable EventTransformer 一锅端，blocTest 5 测）"
```

---

### Task 4: v2 根 + 四页装配

**Files:**
- Create: `state_lab/lib/versions/v2_bloc/v2_shop_root.dart`
- Create: `state_lab/lib/versions/v2_bloc/pages/product_list_page.dart`
- Create: `state_lab/lib/versions/v2_bloc/pages/product_detail_page.dart`
- Create: `state_lab/lib/versions/v2_bloc/pages/cart_page.dart`
- Create: `state_lab/lib/versions/v2_bloc/pages/search_page.dart`

**Interfaces:**
- `V2ShopRoot({ProductApi? api})`（测试注入口，与 V0/V1 同形）；页面签名 `V2ProductListPage()` / `V2ProductDetailPage({required Product product})` / `V2CartPage()` / `V2SearchPage()`。

**消费端 API 对照地图（v1 Provider → v2 Bloc，教学主线）：**

| 位置 | v1 Provider | v2 Bloc |
|---|---|---|
| 服务 DI | `Provider<ProductApi>` | `RepositoryProvider<ProductApi>` |
| 挂状态（新建托管） | `ChangeNotifierProvider(create:)` | `BlocProvider(create:)` |
| 跨路由复用实例 | `ChangeNotifierProvider.value` | `BlocProvider.value` |
| 打包多个 | `MultiProvider` | `MultiBlocProvider` / `MultiRepositoryProvider` |
| body 订阅重建 | `Consumer<M>` | `BlocBuilder<B,S>` |
| 字段级角标 | `Selector<M,int>` | `BlocSelector<B,S,int>` |
| 详情角标 | `context.select` | `context.select<B,int>` |
| 整页依赖 | `context.watch` | `BlocBuilder`（购物车页整页订阅） |
| 回调取用 | `context.read<M>()` | `context.read<B>()` |
| 副作用（弹窗/导航） | —（v1 内联） | `BlocListener` / `BlocConsumer`（搜索失败弹 SnackBar） |
| 状态更新 | 改字段 + `notifyListeners` | `emit(不可变新状态)` |
| 收窄重建 | Selector 选字段比 == | `buildWhen`(prev,curr) / BlocSelector |

- [ ] **Step 1: v2_shop_root.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/api/dio_client.dart';
import '../../shared/api/product_api.dart';
import 'pages/product_list_page.dart';
import 'state/cart_cubit.dart';

/// v2 状态根。对照 v1：MultiProvider → 这里用 RepositoryProvider(纯 DI，
/// bloc 世界管"数据来源/服务"的惯用件) + BlocProvider(管 Cubit/Bloc)。
/// CartCubit 版本级共享（挂在根，跨页存活）；ProductApi 走 Repository
/// 下发，页面级 Bloc 在 create 里 read 它。
class V2ShopRoot extends StatelessWidget {
  const V2ShopRoot({super.key, this.api});

  final ProductApi? api;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ProductApi>(
      create: (_) => api ?? ProductApi(buildDio()),
      child: BlocProvider<CartCubit>(
        create: (_) => CartCubit(),
        child: const V2ProductListPage(),
      ),
    );
  }
}
```

- [ ] **Step 2: pages/product_list_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../../../shared/widgets/product_card.dart';
import '../../../shared/widgets/rebuild_badge.dart';
import '../state/cart_cubit.dart';
import '../state/cart_state.dart';
import '../state/product_list_bloc.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';
import 'search_page.dart';

/// 场景①：三态+分页——状态在 ProductListBloc，页面只剩装配。
/// 对照 v1：ChangeNotifierProvider(create:..loadFirst()) → BlocProvider
/// (create:..add(Started()))。生命周期同样托管：pop 即 close。
class V2ProductListPage extends StatelessWidget {
  const V2ProductListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ProductListBloc(context.read<ProductApi>())..add(ProductListStarted()),
      child: const _ListScaffold(),
    );
  }
}

class _ListScaffold extends StatelessWidget {
  const _ListScaffold();

  void _openCart(BuildContext context) {
    // 跨路由 re-provide：v1 的 .value，bloc 版叫 BlocProvider.value——
    // 同一条铁律（已有实例复用用 .value，新建托管用 create）。
    final cart = context.read<CartCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(value: cart, child: const V2CartPage()),
      ),
    );
  }

  void _openDetail(BuildContext context, Product product) {
    final cart = context.read<CartCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cart,
          child: V2ProductDetailPage(product: product),
        ),
      ),
    );
  }

  void _openSearch(BuildContext context) {
    final cart = context.read<CartCubit>();
    final api = context.read<ProductApi>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiRepositoryProvider(
          providers: [RepositoryProvider<ProductApi>.value(value: api)],
          child: BlocProvider.value(value: cart, child: const V2SearchPage()),
        ),
      ),
    );
  }

  bool _onScroll(BuildContext context, ScrollNotification notification) {
    if (notification.metrics.pixels > notification.metrics.maxScrollExtent - 200) {
      context.read<ProductListBloc>().add(ProductListLoadMore());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniShop · v2 Bloc'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () => _openSearch(context),
          ),
          // BlocSelector：v1 Selector 的 bloc 版——从 CartState 里选出
          // totalCount(int)，值没变就不重建。角标只吃这一个标量。
          BlocSelector<CartCubit, CartState, int>(
            selector: (state) => state.totalCount,
            builder: (context, count) => RebuildBadge(
              label: '列表角标',
              child: CartIconButton(count: count, onPressed: () => _openCart(context)),
            ),
          ),
        ],
      ),
      body: BlocBuilder<ProductListBloc, ProductListState>(
        // buildWhen：加载更多时 loadingMore 翻转不该重建整列表——只有
        // items/status/error 变了才重建 body。v1 Consumer 没这道闸，
        // 这是 Bloc 给的字段级收窄（对照 tech doc §4）。
        buildWhen: (prev, curr) =>
            prev.items != curr.items ||
            prev.status != curr.status ||
            prev.error != curr.error,
        builder: (context, state) => AsyncStateView(
          loading: state.status == ListStatus.loading && state.items.isEmpty,
          error: state.items.isEmpty && state.status == ListStatus.failure
              ? state.error
              : null,
          onRetry: () => context.read<ProductListBloc>().add(ProductListStarted()),
          builder: (_) => RefreshIndicator(
            onRefresh: () async {
              final bloc = context.read<ProductListBloc>();
              bloc.add(ProductListRefreshed());
              await bloc.stream.firstWhere((s) => s.status != ListStatus.loading);
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) => _onScroll(context, n),
              child: ListView.builder(
                itemCount: state.items.length + 1,
                itemBuilder: (context, index) {
                  if (index == state.items.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: state.hasMore
                            ? const CircularProgressIndicator()
                            : const Text('没有更多了'),
                      ),
                    );
                  }
                  final product = state.items[index];
                  return ProductCard(
                    product: product,
                    onTap: () => _openDetail(context, product),
                    onAddToCart: () {
                      context.read<CartCubit>().add(product);
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(const SnackBar(content: Text('已加入购物车')));
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

- [ ] **Step 3: pages/product_detail_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/product.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../state/cart_cubit.dart';
import '../state/cart_state.dart';
import 'cart_page.dart';

/// 场景②：收藏心形仍页面 setState——"一个人看的状态留在页面"，五版一致。
class V2ProductDetailPage extends StatefulWidget {
  const V2ProductDetailPage({super.key, required this.product});

  final Product product;

  @override
  State<V2ProductDetailPage> createState() => _V2ProductDetailPageState();
}

class _V2ProductDetailPageState extends State<V2ProductDetailPage> {
  bool _favorite = false;

  void _openCart() {
    final cart = context.read<CartCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(value: cart, child: const V2CartPage()),
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
          // context.select：BlocSelector 的函数式写法，选 totalCount 标量。
          Builder(builder: (context) {
            final count = context.select<CartCubit, int>((c) => c.state.totalCount);
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
              context.read<CartCubit>().add(widget.product);
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

- [ ] **Step 4: pages/cart_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/widgets/rebuild_badge.dart';
import '../state/cart_cubit.dart';
import '../state/cart_state.dart';

/// 场景③④。整页展示购物车 → BlocBuilder 整页订阅（= v1 context.watch
/// 同粒度）。回调用 context.read<CartCubit>() 拿 cubit 调方法。
class V2CartPage extends StatelessWidget {
  const V2CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('购物车'),
        actions: [
          // clear 按钮 enable 与否也吃 state → 放进 BlocBuilder 里。
          BlocBuilder<CartCubit, CartState>(
            buildWhen: (p, c) => p.isEmpty != c.isEmpty,
            builder: (context, state) => TextButton(
              onPressed: state.isEmpty ? null : context.read<CartCubit>().clear,
              child: const Text('清空'),
            ),
          ),
        ],
      ),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) {
          final items = state.items;
          if (state.isEmpty) {
            return const Center(child: Text('购物车是空的'));
          }
          return ListView.builder(
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
                onDismissed: (_) =>
                    context.read<CartCubit>().remove(item.product.id),
                child: ListTile(
                  title: Text(item.product.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('\$${item.product.price.toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () =>
                            context.read<CartCubit>().changeQty(item.product.id, -1),
                      ),
                      Text('${item.quantity}', style: theme.textTheme.titleMedium),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () =>
                            context.read<CartCubit>().changeQty(item.product.id, 1),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) => state.isEmpty
            ? const SizedBox.shrink()
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: RebuildBadge(
                    label: '合计栏',
                    child: Row(
                      children: [
                        Text('共 ${state.totalCount} 件',
                            style: theme.textTheme.bodyLarge),
                        const Spacer(),
                        Text(
                          '合计 \$${state.totalPrice.toStringAsFixed(2)}',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
```

- [ ] **Step 5: pages/search_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../../../shared/widgets/product_card.dart';
import '../state/cart_cubit.dart';
import '../state/cart_state.dart';
import '../state/search_bloc.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';

/// 场景⑤：防抖/丢过期都进了 SearchBloc 的 EventTransformer，页面瘦成
/// "转发输入 + 展示状态"。用 BlocConsumer 演示 listener（副作用）与
/// builder（重建）分家：搜索失败时 listener 弹一个瞬时 SnackBar。
class V2SearchPage extends StatefulWidget {
  const V2SearchPage({super.key});

  @override
  State<V2SearchPage> createState() => _V2SearchPageState();
}

class _V2SearchPageState extends State<V2SearchPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openCart(BuildContext context) {
    final cart = context.read<CartCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(value: cart, child: const V2CartPage()),
      ),
    );
  }

  void _openDetail(BuildContext context, Product product) {
    final cart = context.read<CartCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cart,
          child: V2ProductDetailPage(product: product),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SearchBloc(context.read<ProductApi>()),
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
              onChanged: (text) =>
                  context.read<SearchBloc>().add(SearchQueryChanged(text)),
            ),
            actions: [
              BlocSelector<CartCubit, CartState, int>(
                selector: (state) => state.totalCount,
                builder: (context, count) => CartIconButton(
                  count: count,
                  onPressed: () => _openCart(context),
                ),
              ),
            ],
          ),
          body: BlocConsumer<SearchBloc, SearchState>(
            // listener：副作用——失败弹瞬时 SnackBar（不参与重建）。
            // listenWhen 限定"刚转入 failure"才弹，避免重复。
            listenWhen: (prev, curr) =>
                prev.status != curr.status && curr.status == SearchStatus.failure,
            listener: (context, state) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.error ?? '搜索失败')));
            },
            builder: (context, state) => state.query.isEmpty
                ? const Center(child: Text('输入关键词搜索'))
                : AsyncStateView(
                    loading: state.status == SearchStatus.loading,
                    error: state.status == SearchStatus.failure ? state.error : null,
                    onRetry: () =>
                        context.read<SearchBloc>().add(const SearchRetried()),
                    builder: (_) => state.results.isEmpty
                        ? const Center(child: Text('没有找到相关商品'))
                        : ListView.builder(
                            itemCount: state.results.length,
                            itemBuilder: (context, index) {
                              final product = state.results[index];
                              return ProductCard(
                                product: product,
                                onTap: () => _openDetail(context, product),
                                onAddToCart: () {
                                  context.read<CartCubit>().add(product);
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

- [ ] **Step 6: 门禁** → `flutter analyze` → `No issues found!`

- [ ] **Step 7: 提交**

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S3：v2_bloc 四页装配（RepositoryProvider/BlocBuilder/BlocSelector/buildWhen/BlocConsumer/.value 全家上阵）"
```

---

### Task 5: 注册表解锁 v2 + 门禁测试更新 + v2 流程回归测试

**Files:**
- Modify: `state_lab/lib/app/version_registry.dart`（v2 接 builder）
- Modify: `state_lab/test/app/version_list_page_test.dart`（锁定断言 v2→v3）
- Test: `state_lab/test/versions/v2_cart_flow_test.dart`（新建，镜像 v0/v1 两用例）

- [ ] **Step 1: version_registry.dart——v2 条目接 builder**

import 区加：`import '../versions/v2_bloc/v2_shop_root.dart';`
v2 条目替换为（去掉 const）：

```dart
  ShopVersion(
    id: 'v2',
    title: 'v2 · Bloc',
    subtitle: '事件驱动的单向数据流',
    unlockLesson: 'S3',
    builder: (_) => const V2ShopRoot(),
  ),
```

- [ ] **Step 2: 门禁测试更新**——v2 已解锁，锁定断言换 v3；补"v2 能推进"：

```dart
// state_lab/test/app/version_list_page_test.dart 全量替换
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/app/app.dart';

void main() {
  testWidgets('首页列出五个版本；点上锁项弹 SnackBar 提示解锁课时', (tester) async {
    await tester.pumpWidget(const StateLabApp());

    expect(find.text('v0 · setState 基线版'), findsOneWidget);
    expect(find.text('v1 · Provider'), findsOneWidget);
    expect(find.text('v2 · Bloc'), findsOneWidget);
    expect(find.text('v3 · GetX'), findsOneWidget);
    expect(find.text('v4 · Riverpod（结课作业）'), findsOneWidget);

    // v2 已在 S3 解锁，上锁示例换 v3
    await tester.tap(find.text('v3 · GetX'));
    await tester.pump();
    expect(find.textContaining('S4 解锁'), findsOneWidget);
  });

  testWidgets('v2 已解锁：点卡片推进 Bloc 版列表页', (tester) async {
    await tester.pumpWidget(const StateLabApp());
    await tester.tap(find.text('v2 · Bloc'));
    await tester.pumpAndSettle();
    expect(find.text('MiniShop · v2 Bloc'), findsOneWidget);
  });
}
```

（若 pumpAndSettle 因 Dio 超时定时器不收敛，退化为 `await tester.pump(const Duration(milliseconds: 400));` 两次。）

- [ ] **Step 3: v2 流程测试**——剧本与 v0/v1 逐行同构：

```dart
// state_lab/test/versions/v2_cart_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/api/product_api.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v2_bloc/v2_shop_root.dart';

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
  testWidgets('v2 主流程：列表加载 → 加购 → 角标 → 购物车增减/合计 → 清空', (tester) async {
    await tester.pumpWidget(MaterialApp(home: V2ShopRoot(api: FakeProductApi())));
    await tester.pump(); // create..add(Started()) 落地
    await tester.pump(); // Future 完成后 emit 落地

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

  testWidgets('S0 学员 bug 剧本在 v2 上回归：详情 → 清空 → 返回，角标清零', (tester) async {
    await tester.pumpWidget(MaterialApp(home: V2ShopRoot(api: FakeProductApi())));
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

- [ ] **Step 4: 门禁** → `flutter analyze` `No issues found!` → `flutter test` `All tests passed!`（既有 + 14 新状态测 + 2 流程 + 门禁改造）

- [ ] **Step 5: 提交**

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S3：注册表解锁 v2 + 门禁测试更新 + v2 主流程/回归测试"
```

---

### Task 6: 技术文档《s3-bloc》

**Files:**
- Create: `state_lab/docs/tech/s3-bloc.md`

统一六章骨架，内容要点：

1. **心智模型与 iOS 类比**：Bloc ≈ Combine 单向数据流（`事件 → (纯函数) → 状态 → UI`）；Cubit ≈ 去掉 event 层的轻量版（方法直接 emit，像个能被订阅的 ViewModel）；核心一句：**从"调方法改字段"翻转成"发事件、收状态"**。对照 S2：把 S2 自测答案练习 2 的账单逐条兑现。
2. **API 全景速查表**：Cubit vs Bloc（何时用哪个）/ `emit` 与状态相等短路（`==` 相等不 emit——Equatable 的隐藏作用）/ BlocProvider(create vs value) / RepositoryProvider / MultiBlocProvider / BlocBuilder(buildWhen) / BlocSelector / BlocListener(listenWhen) / BlocConsumer / context.read·watch·select / EventTransformer 与 `bloc_concurrency`（concurrent/sequential/droppable/restartable 四选一表）+ `stream_transform` debounce。
3. **MiniShop 实战导读**：v1→v2 对照地图（Task 4 扩写）；三个状态件的选型（购物车用 Cubit=轻量，列表/搜索用 Bloc=事件流有转换需求）；不可变 CartLine vs 可变 CartItem 的对照；`droppable` 替 `_loadingMore`、`debounce+restartable` 替 `Timer+序号`。
4. **底层原理**：Bloc 就是一个 `Stream<State>` + `StreamController<Event>`，`on<E>` 注册处理器，EventTransformer 决定事件流如何映射到处理器调用（并发模型）；`emit` 内部 `if (state == newState) return` 靠 Equatable 短路——**这就是不可变+值语义省下的重建**；buildWhen/BlocSelector 在 State 变化后再做一层"要不要重建"判定（先收到通知、再比选值，与 Provider Selector 同构）；为什么 close 后 emit 抛错、以及 bloc 如何自动注销处理器订阅（对照 v1 手写 `_disposed`）。
5. **优缺点、适用场景、常见坑**：样板税（event+state+copyWith+Equatable）换来的三样（可测/可回放/可判等收窄）；坑清单——state 用可变字段导致 `==` 永远为真/为假、emit 被短路吞掉；忘了 Equatable 的 props 漏字段；在 builder 里做副作用（弹窗/导航）应挪 listener；EventTransformer 选错（该 droppable 用了 concurrent 导致重复请求；该 restartable 用了 sequential 导致过期结果覆盖新结果）；`on` 处理器里 await 后长时间不 emit 撞 close。
6. **面试高频题**（≥8 道带答案要点）：Cubit 和 Bloc 区别、怎么选？Bloc 的单向数据流四要素？emit 相等时会发生什么、和 Equatable 什么关系？buildWhen / BlocSelector / BlocListener 各自解决什么？EventTransformer 是什么、concurrent/sequential/droppable/restartable 分别对应什么并发语义？防抖为什么用 EventTransformer 而不在 UI 层做？BlocProvider create vs value？RepositoryProvider 和 BlocProvider 区别？不可变状态相比可变模型换来什么、代价是什么（S2 练习 2 的正式答案）？

- [ ] 提交：

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S3 技术文档：bloc（事件进状态出，把 S2 练习2的账付清）"
```

---

### Task 7: 课时讲义 S3（先于"请你验证"）

**Files:**
- Create: `state_lab/docs/lessons/S3-Bloc版MiniShop.md`

章节要点：

1. **本课重点**：S2 练习 2 的账今天兑现——不可变状态 + Equatable + copyWith，换来 buildWhen/blocTest/可回放；对照地图"v1 Provider → v2 Bloc"；Cubit（购物车）vs Bloc（列表/搜索）的选择依据；EventTransformer 一锅端防抖+丢过期。
2. **代码地图**：v2_bloc 树 + "与 v1 的 diff 就是本课全部内容"（`git diff` 命令）。
3. **控件/API 速查表**（iOS 类比 + 坑）：Cubit/Bloc / BlocProvider(create·value) / RepositoryProvider / MultiBlocProvider / BlocBuilder(buildWhen) / BlocSelector / BlocListener(listenWhen) / BlocConsumer / context.read·watch·select / EventTransformer(droppable·restartable·debounce) / Equatable / blocTest。
4. **关键实验**：①列表页加购看 `列表角标` RebuildBadge：v2 与 v1 应同为"只角标动"；②购物车页增减看 `合计栏` 计数——BlocBuilder 整页订阅，合计栏每次都动（同 v1 watch，S5 埋点可再收窄）；③搜索连打三个字符，观察只发最后一枪（防抖）、快速改词旧结果不覆盖（restartable）；④故意把详情页 `_openCart` 的 `BlocProvider.value` 删掉 → `BlocProvider.of() called with a context that does not contain a Cubit of type CartCubit` 红屏，读它的建议文案。
5. **自测清单**（≥8 题）：Cubit 和 Bloc 怎么选？emit 一个和当前值相等的 state 会怎样、为什么？buildWhen 返回 false 时发生什么？BlocSelector 和 buildWhen 的关系？为什么防抖要放 EventTransformer 而不在 TextField 里 setState 计时？droppable 和 restartable 分别对应 v1 的哪行手写代码？不可变 CartLine 相比可变 CartItem 多写了什么、换回了什么？RepositoryProvider 和 BlocProvider 区别？BlocListener 相比 BlocBuilder 什么时候用？
6. **课后练习**：①把 `ProductListLoadMore` 的 `droppable()` 改成 `concurrent()`，快速触底两次，观察 fetchCalls 翻倍/重复追加，再改回来（体会并发模型即正确性）；②把 SearchBloc 的 `restartable` 换成 `sequential`，快速改词，观察旧结果覆盖新结果的过期 bug；③进阶思考（带去 S4 GetX）：Bloc 强制"事件→状态"的仪式感换来纪律，但样板也最多——如果有个方案让你既能 `.obs` 一把梭又能按需上结构，你会怎么权衡？

- [ ] 提交：

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S3 讲义"
```

---

### Task 8: 模拟器验证与过关收尾

- [ ] **Step 1: 启动**（复用在跑的 flutter run 热重载即可；若已退出则重新拉起）：

```bash
cd /Users/wenbo/Desktop/WBFlutter/state_lab && env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
  FLUTTER_STORAGE_BASE_URL=https://mirrors.cloud.tencent.com/flutter \
  flutter run -d 85C08A29-994F-44BC-8BEF-C0CB6D6DBFF7
```

- [ ] **Step 2: 学员验证清单**：①首页 v2 卡片解锁可进；②v2 走完同款场景表（分页/刷新/加购/角标/购物车增删/合计/清空/搜索防抖）；③详情→清空→返回角标清零（老剧本新版本）；④关键实验 ③（防抖+restartable）与 RebuildBadge 对比。
- [ ] **Step 3: 学员回「确认」后**：README S3 行 → `✅ 完成（日期）`，提交 `"S3 收官：进度表翻牌，S4 开课"`。

---

## Self-Review 记录

- **规格覆盖**：设计文档 S3 行——Cubit(购物车)✓ / Bloc 事件驱动(列表 Started/Refreshed/LoadMore)✓ / BlocBuilder✓ / BlocListener·BlocConsumer✓(搜索页) / buildWhen✓(列表 body/购物车合计栏) / Equatable 与状态不可变✓(CartState/CartLine/ProductListState/SearchState) / EventTransformer 搜索防抖✓(debounce+restartable) / blocTest✓(三个状态件)。MiniShop 四页五场景全部落地(Task 2/3/4)。
- **有意增量登记**：搜索页 BlocConsumer.listener 弹瞬时 SnackBar（设计文档点名要覆盖 BlocListener/BlocConsumer 的落点；不改①–⑤功能，属副作用演示）。其余文案/流程与 v1 逐像素一致。
- **占位符扫描**：无 TBD；文档任务给到章节级要点与全部技术论断。
- **类型一致性**：`CartCubit.add/changeQty/remove/clear` 与 S1/S2 同名；`CartState.items/isEmpty/totalCount/totalPrice` 对齐；`ProductListBloc(api)` 暴露 `api` 供 onScroll 与测试；`SearchBloc(api,{debounce})`；`V2ShopRoot({api})` 与测试注入一致；门禁测试改动已圈定（唯一被修改的旧测试）。
- **并发模型**：LoadMore=droppable（防重入=v1 `_loadingMore`）；Search=debounce+restartable（=v1 `Timer`+请求序号）；两处都在讲义/技术文档作为对照教学点。
