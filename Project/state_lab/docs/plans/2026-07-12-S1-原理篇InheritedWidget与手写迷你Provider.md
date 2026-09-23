# S1 原理篇：InheritedWidget 与手写迷你 Provider 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 打穿所有状态管理方案的共同地基——手写一个 ~40 行核心逻辑的迷你 Provider（InheritedNotifier 思路），用它就地重构 v0，让 S0 的四大痛点结构性消失；沉淀技术文档《s1-状态管理的地基》。

**Architecture:** 新增 `CartController extends ChangeNotifier`（把"改数据"和"发通知"锁进同一扇门）+ `MiniProvider<T extends Listenable>`（InheritedWidget + 自定义 InheritedElement 订阅 Listenable，即 framework 里 InheritedNotifier 的实现结构）。v0 五个文件就地重构：根变成 provider 宿主，四个页面砍掉购物车相关构造参数，用 `MiniProvider.of/read` 自取自订阅。**既有 13 个测试原样不动、必须全绿**——尤其学员抓的 pop 返回陈旧 bug 回归测试，在删掉所有 `await push + setState` 手工补丁后依然通过，这就是结构性修复的证明。

**Tech Stack:** 纯 Flutter framework（InheritedWidget / InheritedElement / ChangeNotifier），本课不引入任何第三方状态库——这是"地基课"的纪律。

## Global Constraints

- Flutter 3.44.4 stable；`flutter analyze` 0 issue、全量 `flutter test` 绿是每个任务的过关线。
- `shared/` 纯净硬约束不变：MiniProvider / CartController 属于状态层，放 `lib/versions/v0_setstate/state/`，**禁止**进 `shared/`。
- 既有测试 `test/versions/v0_cart_flow_test.dart` **一行不许改**——它是重构的安全网。
- git 只 `git -C /Users/wenbo/Desktop/WBFlutter add state_lab/`，中文提交信息，一任务一提交。重构前最后一个纯 v0 提交是 `93abcd2`（痛点原版随时 `git show` 回看）。
- 课时讲义（Task 5）必须在发出任何"请你验证"消息之前写好（教学硬约束）。
- 模拟器：iPhone 17 `85C08A29-994F-44BC-8BEF-C0CB6D6DBFF7`；`flutter run` 带镜像环境变量（见 Task 6），绝不用 `flutter build ios --simulator`。
- 本课不改 `shared/models/`（JSON 解析已定 json_serializable，与本课无关）。

---

### Task 1: CartController 状态层（ChangeNotifier，TDD）

**Files:**
- Create: `state_lab/lib/versions/v0_setstate/state/cart_controller.dart`
- Test: `state_lab/test/versions/v0_setstate/cart_controller_test.dart`

**Interfaces:**
- Consumes: `shared/models/cart_item.dart` 的 `CartItem(product:, quantity:)`（可变 `quantity`、`lineTotal` getter）、`shared/models/product.dart` 的 `Product`。
- Produces: `CartController`，API 供 Task 2/3 使用——`List<CartItem> get items`（不可变视图）、`bool get isEmpty`、`int get totalCount`、`double get totalPrice`、`void add(Product)`、`void changeQty(int productId, int delta)`（减到 ≤0 自动移除）、`void remove(int productId)`、`void clear()`。每个变更方法末尾 `notifyListeners()`。

- [ ] **Step 1: 写失败测试**

```dart
// state_lab/test/versions/v0_setstate/cart_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v0_setstate/state/cart_controller.dart';

const _p1 = Product(id: 1, title: 'A', description: 'a', price: 9.99,
    thumbnail: 'x', rating: 4.5);
const _p2 = Product(id: 2, title: 'B', description: 'b', price: 5.01,
    thumbnail: 'x', rating: 4.0);

void main() {
  group('CartController', () {
    test('add：新商品入车；重复加购只涨数量不加行', () {
      final cart = CartController();
      cart.add(_p1);
      cart.add(_p1);
      cart.add(_p2);
      expect(cart.items.length, 2);
      expect(cart.items.first.quantity, 2);
    });

    test('changeQty：增减数量，减到 0 自动移除', () {
      final cart = CartController();
      cart.add(_p1);
      cart.changeQty(1, 1);
      expect(cart.items.first.quantity, 2);
      cart.changeQty(1, -2);
      expect(cart.isEmpty, isTrue);
    });

    test('remove / clear', () {
      final cart = CartController();
      cart.add(_p1);
      cart.add(_p2);
      cart.remove(1);
      expect(cart.items.single.product.id, 2);
      cart.clear();
      expect(cart.isEmpty, isTrue);
    });

    test('派生值 totalCount / totalPrice 现算', () {
      final cart = CartController();
      cart.add(_p1);
      cart.changeQty(1, 1); // 9.99 × 2
      cart.add(_p2); // + 5.01
      expect(cart.totalCount, 3);
      expect(cart.totalPrice, closeTo(24.99, 0.001));
    });

    test('每次变更恰好通知一次监听者（改和通知锁进同一扇门）', () {
      final cart = CartController();
      var fired = 0;
      cart.addListener(() => fired++);
      cart.add(_p1); // 1
      cart.changeQty(1, 1); // 2
      cart.remove(1); // 3
      cart.clear(); // 4
      expect(fired, 4);
    });

    test('items 是只读视图：外部改不动，想改必须走方法', () {
      final cart = CartController();
      cart.add(_p1);
      expect(() => cart.items.clear(), throwsUnsupportedError);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd /Users/wenbo/Desktop/WBFlutter/state_lab && flutter test test/versions/v0_setstate/cart_controller_test.dart`
Expected: 编译失败——`Error: Couldn't resolve ... state/cart_controller.dart`（文件还不存在）。

- [ ] **Step 3: 最小实现**

```dart
// state_lab/lib/versions/v0_setstate/state/cart_controller.dart
import 'package:flutter/foundation.dart';

import '../../../shared/models/cart_item.dart';
import '../../../shared/models/product.dart';

/// S1 重构版购物车状态层：把「改数据」和「发通知」锁进同一扇门。
/// v0 的根病灶是"谁都能改裸 List、没人负责通知"——现在改必须走方法，
/// 方法里必发 notifyListeners，"改了没人知道"从结构上不可能发生。
/// 类比 iOS：ObservableObject；notifyListeners ≈ objectWillChange.send()。
class CartController extends ChangeNotifier {
  final List<CartItem> _items = [];

  /// 只读视图（List.unmodifiable）：外部拿不到可变引用。
  List<CartItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  /// 派生状态照旧 getter 现算（场景④原则不变，理由见 S0 自测 3）。
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

  /// 数量增减；减到 0 自动移除（逻辑从 _V0ShopRootState 原样搬来）。
  void changeQty(int productId, int delta) {
    final index = _items.indexWhere((it) => it.product.id == productId);
    if (index < 0) return; // 没这条目：什么都没变，不发通知
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

Run: `flutter test test/versions/v0_setstate/cart_controller_test.dart`
Expected: `All tests passed!`（6 个用例）

- [ ] **Step 5: 提交**

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S1：CartController 状态层（改与通知同门，TDD 6 测）"
```

---

### Task 2: 手写 MiniProvider（InheritedNotifier 思路，TDD）

**Files:**
- Create: `state_lab/lib/versions/v0_setstate/state/mini_provider.dart`
- Test: `state_lab/test/versions/v0_setstate/mini_provider_test.dart`

**Interfaces:**
- Consumes: 无（纯 framework）。
- Produces: `MiniProvider<T extends Listenable>`——构造 `MiniProvider({required T notifier, required Widget child})`；`static T of<T extends Listenable>(BuildContext)`（取值 + 注册依赖，notifier 开火时调用方重建）；`static T read<T extends Listenable>(BuildContext)`（只取值不订阅，事件回调用）。找不到 provider 时两者都给带类型名的断言错误。

- [ ] **Step 1: 写失败测试**

```dart
// state_lab/test/versions/v0_setstate/mini_provider_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/versions/v0_setstate/state/mini_provider.dart';

/// 最小 Listenable：一个会通知的计数器。
class _Counter extends ChangeNotifier {
  int value = 0;
  void increment() {
    value++;
    notifyListeners();
  }
}

void main() {
  testWidgets('of() 取到树上提供的同一个实例', (tester) async {
    final counter = _Counter();
    _Counter? got;
    await tester.pumpWidget(MiniProvider(
      notifier: counter,
      child: Builder(builder: (context) {
        got = MiniProvider.of<_Counter>(context);
        return const SizedBox();
      }),
    ));
    expect(identical(got, counter), isTrue);
  });

  testWidgets('notifyListeners 后，of() 的依赖者自动重建', (tester) async {
    final counter = _Counter();
    var builds = 0;
    await tester.pumpWidget(MaterialApp(
      home: MiniProvider(
        notifier: counter,
        child: Builder(builder: (context) {
          final c = MiniProvider.of<_Counter>(context);
          builds++;
          return Text('${c.value}');
        }),
      ),
    ));
    expect(builds, 1);
    expect(find.text('0'), findsOneWidget);

    counter.increment(); // 没有任何 setState！
    await tester.pump();
    expect(builds, 2);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('read() 只取值不订阅：notifyListeners 后不重建', (tester) async {
    final counter = _Counter();
    var builds = 0;
    await tester.pumpWidget(MaterialApp(
      home: MiniProvider(
        notifier: counter,
        child: Builder(builder: (context) {
          MiniProvider.read<_Counter>(context);
          builds++;
          return const Text('static');
        }),
      ),
    ));
    expect(builds, 1);

    counter.increment();
    await tester.pump();
    expect(builds, 1); // 没订阅就不陪跑——这是 of/read 的全部区别
  });

  testWidgets('树上没有 MiniProvider 时，of()/read() 给出可读断言', (tester) async {
    await tester.pumpWidget(Builder(builder: (context) {
      expect(() => MiniProvider.of<_Counter>(context), throwsAssertionError);
      expect(() => MiniProvider.read<_Counter>(context), throwsAssertionError);
      return const SizedBox();
    }));
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/versions/v0_setstate/mini_provider_test.dart`
Expected: 编译失败（mini_provider.dart 不存在）。

- [ ] **Step 3: 最小实现**

```dart
// state_lab/lib/versions/v0_setstate/state/mini_provider.dart
import 'package:flutter/widgets.dart';

/// 手写迷你 Provider：InheritedWidget + Listenable 的胶水（约 40 行核心逻辑）。
/// 这就是 framework 里 InheritedNotifier 的实现结构——写完可以打开
/// flutter/lib/src/widgets/inherited_notifier.dart 逐行对照。
/// 类比 iOS：.environmentObject(model) 挂树 + @EnvironmentObject 取用自动刷新。
class MiniProvider<T extends Listenable> extends InheritedWidget {
  const MiniProvider({super.key, required this.notifier, required super.child});

  final T notifier;

  /// 取值 + 注册依赖（≈ @EnvironmentObject / 后面 Provider 的 context.watch）。
  /// dependOn... 做了两件事：O(1) 查表拿到祖先 provider + 把调用方登记进
  /// 它的依赖名单。notifier 每次开火，名单上的 Element 挨个重建。
  static T of<T extends Listenable>(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<MiniProvider<T>>();
    assert(provider != null, '往上找不到 MiniProvider<$T>：这条路由包了吗？');
    return provider!.notifier;
  }

  /// 只取值、不登记依赖（≈ 后面 Provider 的 context.read）。
  /// 事件回调里用它——回调不是 build，不需要"数据变了重跑一遍"。
  static T read<T extends Listenable>(BuildContext context) {
    final provider = context.getInheritedWidgetOfExactType<MiniProvider<T>>();
    assert(provider != null, '往上找不到 MiniProvider<$T>：这条路由包了吗？');
    return provider!.notifier;
  }

  /// 只在 widget 实例被替换时走到（父级重建/热重载传了新 notifier）。
  /// 日常 notifyListeners 的刷新不走这里——走下面 Element 的订阅。
  @override
  bool updateShouldNotify(MiniProvider<T> oldWidget) =>
      notifier != oldWidget.notifier;

  @override
  InheritedElement createElement() => _MiniProviderElement<T>(this);
}

/// 自定义 Element：真正的"通知引擎"。
/// InheritedWidget 天生只会在**自己被替换**时通知依赖者；想要
/// "notifier 开火 → 依赖者重建"，必须有人订阅 notifier——就是这个 Element。
class _MiniProviderElement<T extends Listenable> extends InheritedElement {
  _MiniProviderElement(MiniProvider<T> widget) : super(widget) {
    widget.notifier.addListener(_handleUpdate); // 上树即订阅
  }

  bool _dirty = false;

  @override
  void update(MiniProvider<T> newWidget) {
    // 父级重建换了 notifier 实例：退订旧的、订上新的。
    final oldNotifier = (widget as MiniProvider<T>).notifier;
    if (oldNotifier != newWidget.notifier) {
      oldNotifier.removeListener(_handleUpdate);
      newWidget.notifier.addListener(_handleUpdate);
    }
    super.update(newWidget);
  }

  void _handleUpdate() {
    _dirty = true;
    markNeedsBuild(); // 排队到下一帧：build 里把消息扩散给依赖者
  }

  @override
  Widget build() {
    if (_dirty) {
      notifyClients(widget as MiniProvider<T>); // 挨个喊依赖者 didChangeDependencies
      _dirty = false;
    }
    return super.build();
  }

  @override
  void unmount() {
    (widget as MiniProvider<T>).notifier.removeListener(_handleUpdate); // 防泄漏
    super.unmount();
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/versions/v0_setstate/mini_provider_test.dart`
Expected: `All tests passed!`（4 个用例）

- [ ] **Step 5: 提交**

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S1：手写迷你 Provider（InheritedNotifier 思路，TDD 4 测）"
```

---

### Task 3: v0 就地重构——五个文件换水管

**Files:**
- Modify: `state_lab/lib/versions/v0_setstate/v0_shop_root.dart`（全量替换）
- Modify: `state_lab/lib/versions/v0_setstate/pages/product_list_page.dart`（全量替换）
- Modify: `state_lab/lib/versions/v0_setstate/pages/product_detail_page.dart`（全量替换）
- Modify: `state_lab/lib/versions/v0_setstate/pages/cart_page.dart`（全量替换）
- Modify: `state_lab/lib/versions/v0_setstate/pages/search_page.dart`（全量替换）
- Test: **不新增**，安全网 = 既有 `test/versions/v0_cart_flow_test.dart`（一行不改）+ 全量 13 测。

**Interfaces:**
- Consumes: Task 1 的 `CartController`（items/isEmpty/totalCount/totalPrice/add/changeQty/remove/clear）、Task 2 的 `MiniProvider.of/read`。
- Produces: 页面新签名——`V0ProductListPage({required ProductApi api})`、`V0ProductDetailPage({required Product product})`、`V0CartPage()`（无参、变 StatelessWidget）、`V0SearchPage({required ProductApi api})`。`V0ShopRoot(api:)` 对外签名不变（测试依赖它）。

**关键设计（讲给学员的三句话）：**
1. **InheritedWidget 不跨路由**：查找走 Element 父链，push 出去的页面挂在 Navigator 下面、不在本页子树里——所以每条 push 都要把**同一个 controller 实例**再包一层 MiniProvider 带过去（S2 会看到 Provider 的 `.value` 干的就是这件事）。
2. **依赖粒度 = 调 of() 的那个 Element**：列表页把 `of()` 收进 AppBar 里的一个 `Builder`，购物车变化时只有角标那一小块重建，整页和商品卡都不陪跑——RebuildBadge 计数就是证据（S0 课后练习的对照实验）。
3. **双重 setState / await+setState 补丁全部删除**：通知走 controller → MiniProvider element → 依赖者，一份状态一处通知。

- [ ] **Step 1: 全量替换 v0_shop_root.dart**

```dart
import 'package:flutter/material.dart';

import '../../shared/api/dio_client.dart';
import '../../shared/api/product_api.dart';
import 'pages/product_list_page.dart';
import 'state/cart_controller.dart';
import 'state/mini_provider.dart';

/// v0 状态根（S1 就地重构版）：共享状态从"裸 List + 回调森林"收编为
/// CartController，由 MiniProvider 挂到树上——子孙自取自订阅，
/// 根不再当快递中转站。层层传参原版见 git 历史 93abcd2。
class V0ShopRoot extends StatefulWidget {
  const V0ShopRoot({super.key, this.api});

  /// 可注入的 API（测试传 Fake；生产走 DummyJSON）。
  final ProductApi? api;

  @override
  State<V0ShopRoot> createState() => _V0ShopRootState();
}

class _V0ShopRootState extends State<V0ShopRoot> {
  late final ProductApi _api = widget.api ?? ProductApi(buildDio());

  /// 控制器生命周期归根管（≈ 根 VC 持有 viewModel，deinit 一起走）。
  final CartController _cart = CartController();

  @override
  void dispose() {
    _cart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ 这层 MiniProvider 只罩得住本路由的子树（列表页）。
    // detail/cart/search 是 push 出去的兄弟路由，不在这棵 Element 树里，
    // 往上找不到它——所以每条 push 要用同一个 _cart 再包一层（见各页 _openXxx）。
    // 这是 InheritedWidget 的著名边界：查找走 Element 父链，不跨路由。
    return MiniProvider(
      notifier: _cart,
      child: V0ProductListPage(api: _api),
    );
  }
}
```

- [ ] **Step 2: 全量替换 product_list_page.dart**

```dart
import 'package:flutter/material.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../../../shared/widgets/product_card.dart';
import '../../../shared/widgets/rebuild_badge.dart';
import '../state/cart_controller.dart';
import '../state/mini_provider.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';
import 'search_page.dart';

/// 场景①：异步三态 + 分页——这些是页面私有状态，**继续用 setState**，
/// 这是它的舒适区。S1 只把"跨页共享"的购物车换了水管。
/// ⭐ S0 痛点展品 1 谢幕：构造函数从 6 参砍到 1 参，"快递中转站"下岗。
class V0ProductListPage extends StatefulWidget {
  const V0ProductListPage({super.key, required this.api});

  final ProductApi api;

  @override
  State<V0ProductListPage> createState() => _V0ProductListPageState();
}

class _V0ProductListPageState extends State<V0ProductListPage> {
  final List<Product> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  bool _hasMore = true;
  int _skip = 0;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.api.fetchProducts(skip: 0);
      if (!mounted) return; // 异步回来页面可能已销毁（≈ weak self 判空）
      setState(() {
        _items
          ..clear()
          ..addAll(page.products);
        _skip = page.products.length;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败：$e';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return; // 防重：正在加载/没有更多就不再发
    setState(() => _loadingMore = true);
    try {
      final page = await widget.api.fetchProducts(skip: _skip);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.products);
        _skip += page.products.length;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false); // 加载更多失败不打断已有列表
    }
  }

  /// ≈ scrollViewDidScroll：滚到离底部 200 以内就预取下一页。
  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.pixels >
        notification.metrics.maxScrollExtent - 200) {
      _loadMore();
    }
    return false; // 不拦截，让通知继续冒泡
  }

  void _openCart() {
    // push 出去的路由接不到本页头顶的 MiniProvider——
    // 把同一个 controller 实例再包一层带过去（≈ Provider 的 .value 用法）。
    final cart = MiniProvider.read<CartController>(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MiniProvider(notifier: cart, child: const V0CartPage()),
      ),
    );
  }

  void _openDetail(Product product) {
    // 对照 S0：这里曾经手递 6 个参数。现在只递业务参数 product。
    final cart = MiniProvider.read<CartController>(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MiniProvider(
          notifier: cart,
          child: V0ProductDetailPage(product: product),
        ),
      ),
    );
  }

  void _openSearch() {
    final cart = MiniProvider.read<CartController>(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MiniProvider(
          notifier: cart,
          child: V0SearchPage(api: widget.api),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniShop · v0 setState+迷你Provider'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: _openSearch,
          ),
          // ⭐ 依赖粒度实验：of() 收进这个 Builder，购物车变化时
          // 只有它重建——整页、商品卡都不陪跑（S0 痛点 4 的第一刀）。
          // RebuildBadge 计数对比 S0：加购一件，卡片计数纹丝不动。
          Builder(builder: (context) {
            final cart = MiniProvider.of<CartController>(context);
            return RebuildBadge(
              label: '列表角标',
              child: CartIconButton(
                count: cart.totalCount,
                onPressed: _openCart,
              ),
            );
          }),
        ],
      ),
      body: AsyncStateView(
        // 有旧数据时刷新不闪全屏 loading（契约见 AsyncStateView 注释）
        loading: _loading && _items.isEmpty,
        error: _items.isEmpty ? _error : null,
        onRetry: _loadFirstPage,
        builder: (_) => RefreshIndicator(
          onRefresh: _loadFirstPage,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ListView.builder(
              // +1 是列表末尾的 footer（加载中 / 没有更多了）
              itemCount: _items.length + 1,
              itemBuilder: (context, index) {
                if (index == _items.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: _hasMore
                          ? const CircularProgressIndicator()
                          : const Text('没有更多了'),
                    ),
                  );
                }
                final product = _items[index];
                return ProductCard(
                  product: product,
                  onTap: () => _openDetail(product),
                  onAddToCart: () {
                    // 事件回调用 read：只调方法，不需要订阅。
                    MiniProvider.read<CartController>(context).add(product);
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
    );
  }
}
```

- [ ] **Step 3: 全量替换 product_detail_page.dart**

```dart
import 'package:flutter/material.dart';

import '../../../shared/models/product.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../state/cart_controller.dart';
import '../state/mini_provider.dart';
import 'cart_page.dart';

/// 场景②：收藏心形是**局部 UI 状态**，继续 setState——五个版本它都不进全局。
/// ⭐ S0 痛点展品 2、3 谢幕：加购不再双重 setState；进购物车不再
/// await + 手动补刷——角标的 Builder 依赖着 controller，谁改都自动跟。
class V0ProductDetailPage extends StatefulWidget {
  const V0ProductDetailPage({super.key, required this.product});

  final Product product;

  @override
  State<V0ProductDetailPage> createState() => _V0ProductDetailPageState();
}

class _V0ProductDetailPageState extends State<V0ProductDetailPage> {
  bool _favorite = false;

  void _openCart() {
    // 对照 S0：这里曾是 await push + if(mounted) setState 的手工补丁。
    // 现在购物车页清空 → controller 开火 → 本页角标 Builder（依赖者）
    // 立刻重建——pop 回来看到的必然是新值，痛点 3 结构性消失。
    final cart = MiniProvider.read<CartController>(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MiniProvider(notifier: cart, child: const V0CartPage()),
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
            // 局部状态：本页 setState 就够了，跟谁都不共享。
            onPressed: () => setState(() => _favorite = !_favorite),
          ),
          Builder(builder: (context) {
            final cart = MiniProvider.of<CartController>(context);
            return CartIconButton(count: cart.totalCount, onPressed: _openCart);
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
              // 一份状态、一处通知：不再需要"根一次 + 本页一次"。
              MiniProvider.read<CartController>(context).add(widget.product);
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

- [ ] **Step 4: 全量替换 cart_page.dart**

```dart
import 'package:flutter/material.dart';

import '../../../shared/widgets/rebuild_badge.dart';
import '../state/cart_controller.dart';
import '../state/mini_provider.dart';

/// 场景③跨页共享 + 场景④派生状态。
/// ⭐ 看类型：StatefulWidget → StatelessWidget。S0 时本页没有任何
/// 自己的状态，却被迫 Stateful——只为能 setState 通知自己。
/// 现在整页在 build 里 of() 依赖 controller：谁改购物车，本页自动重建。
class V0CartPage extends StatelessWidget {
  const V0CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 整页都在展示购物车——页面级依赖是合理粒度，直接在页面 build 里 of()。
    final cart = MiniProvider.of<CartController>(context);
    final items = cart.items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('购物车'),
        actions: [
          TextButton(
            // 对照 S0：这里曾是 onClearCart() + setState(){} 双保险。
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
                  // onDismissed 仍须立刻删数据（Dismissible 铁律），
                  // remove 里自带 notifyListeners，本页跟着重建。
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

- [ ] **Step 5: 全量替换 search_page.dart**

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../../../shared/widgets/product_card.dart';
import '../state/cart_controller.dart';
import '../state/mini_provider.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';

/// 场景⑤：防抖 400ms + 序号丢过期——输入流是页面私有状态，继续 setState。
/// ⭐ 对照 S0：_openCart/_openDetail 的 await+setState 补丁删除；
/// 加购后的"本页角标 setState"删除——角标 Builder 自动跟。
class V0SearchPage extends StatefulWidget {
  const V0SearchPage({super.key, required this.api});

  final ProductApi api;

  @override
  State<V0SearchPage> createState() => _V0SearchPageState();
}

class _V0SearchPageState extends State<V0SearchPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<Product> _results = [];
  bool _loading = false;
  String? _error;
  String _lastQuery = '';

  /// 请求序号：只有"最新一发"的结果才允许落地（手搓版 switchToLatest）。
  int _requestSeq = 0;

  @override
  void dispose() {
    _debounce?.cancel(); // 忘了 cancel，页面销毁后 Timer 还会开火（≈ 悬垂闭包）
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel(); // 每次输入都推倒重来——这就是防抖
    _debounce = Timer(
      const Duration(milliseconds: 400), // 设计文档冻结值
      () => _search(text.trim()),
    );
  }

  Future<void> _search(String query) async {
    _lastQuery = query;
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.api.searchProducts(query);
      if (!mounted || seq != _requestSeq) return; // 过期响应，扔
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        _error = '搜索失败：$e';
      });
    }
  }

  void _openCart() {
    final cart = MiniProvider.read<CartController>(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MiniProvider(notifier: cart, child: const V0CartPage()),
      ),
    );
  }

  void _openDetail(Product product) {
    final cart = MiniProvider.read<CartController>(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MiniProvider(
          notifier: cart,
          child: V0ProductDetailPage(product: product),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索商品（如 phone）',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
        actions: [
          Builder(builder: (context) {
            final cart = MiniProvider.of<CartController>(context);
            return CartIconButton(count: cart.totalCount, onPressed: _openCart);
          }),
        ],
      ),
      body: _lastQuery.isEmpty
          ? const Center(child: Text('输入关键词搜索'))
          : AsyncStateView(
              loading: _loading,
              error: _error,
              onRetry: () => _search(_lastQuery),
              builder: (_) => _results.isEmpty
                  ? const Center(child: Text('没有找到相关商品'))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final product = _results[index];
                        return ProductCard(
                          product: product,
                          onTap: () => _openDetail(product),
                          onAddToCart: () {
                            MiniProvider.read<CartController>(context)
                                .add(product);
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(const SnackBar(
                                  content: Text('已加入购物车')));
                          },
                        );
                      },
                    ),
            ),
    );
  }
}
```

- [ ] **Step 6: 跑门禁**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test`
Expected: `All tests passed!`（13 旧 + 10 新 = 23 测）。重点看 `v0_cart_flow_test.dart` 第二个用例（学员抓的 pop 陈旧 bug）：手工补丁全删了它还绿——结构性修复的铁证。

- [ ] **Step 7: 提交**

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S1：v0 就地重构——迷你 Provider 换掉层层传参与双重 setState（旧测试原样全绿）"
```

---

### Task 4: 技术文档《s1-状态管理的地基》

**Files:**
- Create: `state_lab/docs/tech/s1-状态管理的地基.md`

**Interfaces:**
- Consumes: Task 1–3 的代码作为实战导读的指向对象。
- Produces: 深度技术文档，S2–S4 每篇技术文档的"底层原理"章都会回链到它。

- [ ] **Step 1: 按设计文档统一骨架写全文**，六章内容要点（写作时展开为完整长文，每章配代码/图）：

1. **心智模型与 iOS 类比**：InheritedWidget ≈ SwiftUI `Environment`（沿树向下注入、按类型查找）；ChangeNotifier ≈ `ObservableObject`（`notifyListeners` ≈ `objectWillChange.send()`）；ValueNotifier ≈ `@Published` 单值；ListenableBuilder ≈ 手动 `sink/assign` 订阅点。核心一句话：**所有 Flutter 状态管理 = "把对象挂到树上让子孙找到（DI）" + "对象变了通知谁重建（订阅）"** 两件事的不同答案。
2. **API 全景速查表**：InheritedWidget / `updateShouldNotify` / `dependOnInheritedWidgetOfExactType` / `getInheritedWidgetOfExactType`（取不订阅）/ `InheritedNotifier` / `InheritedModel`（aspect 一句话定位）/ ChangeNotifier（`addListener/removeListener/notifyListeners/dispose`）/ ValueNotifier / ListenableBuilder / ValueListenableBuilder / AnimatedBuilder（就是 ListenableBuilder 的动画名）。每行：用途、怎么用、坑。
3. **MiniShop 实战导读**：指向 `versions/v0_setstate/state/`，讲 CartController（改与通知同门、只读视图封死裸改）、MiniProvider（of/read 两条路）、三处关键 diff（根、列表页 Builder 圈依赖、购物车页变 Stateless）。对照 `git show 93abcd2` 看重构前后。
4. **底层原理（本文档的灵魂）**：
   - 查找为什么是 O(1)：每个 Element 携带 `_inheritedElements` 哈希表（Type → InheritedElement，PersistentHashMap），InheritedElement 挂载时把自己登记进去再传给子树——`dependOn` 是查表，不是爬树。
   - 依赖注册：`dependOnInheritedWidgetOfExactType` = 查表 + `setDependencies`（把调用方 Element 记进 provider element 的 `_dependents`）。
   - 通知路径两条：① widget 实例被替换 → `updated()` 里问 `updateShouldNotify` → `notifyClients`；② notifier 开火 → 自定义 element `_handleUpdate` → `markNeedsBuild` → 下一帧 `build()` 里 `notifyClients` → 依赖者 `didChangeDependencies` → `markNeedsBuild`。我们手写的 MiniProvider 就是路径②，与 framework `inherited_notifier.dart` 逐行对照。
   - 为什么不跨路由：查找走 Element 父链上收集的表；pushed 路由挂在 Navigator/Overlay 之下，不在 provider 子树里。两种解法：provider 提到 Navigator 之上（Provider 的标准姿势）/ 每条路由 re-provide 同一实例（本课姿势，即 `.value`）。
   - `dependOn` 只能在 build/didChangeDependencies 里调、不能在 initState（Element 还没到 active 期），`read` 不受限——正是 of/read 分工的框架级原因。
5. **优缺点、适用场景、常见坑**：InheritedWidget 裸用样板重（要套 Stateful 管生命周期，Provider 替你干的就是这个）；坑：of() 忘包路由报错、在 initState 里 dependOn、notifier 不 dispose 泄漏、`updateShouldNotify` 返回 true 风暴。
6. **面试高频题**（带答案要点，≥8 题）：InheritedWidget 如何实现 O(1) 查找？updateShouldNotify 何时被调？didChangeDependencies 和 build 的关系？Provider 和 InheritedWidget 的关系？context.watch/read 区别及各自能在哪调？为什么 InheritedWidget 不跨路由？ChangeNotifier 和 ValueNotifier 选谁？InheritedModel 的 aspect 解决什么？

- [ ] **Step 2: 提交**

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S1 技术文档：状态管理的地基（InheritedWidget/ChangeNotifier 原理）"
```

---

### Task 5: 课时讲义 S1（必须在"请验证"之前完成）

**Files:**
- Create: `state_lab/docs/lessons/S1-原理篇InheritedWidget与手写迷你Provider.md`

**Interfaces:**
- Consumes: Task 1–4 全部产出。
- Produces: 课时讲义（薄，引用技术文档不复制），含自测清单——自测答案等学员做完后归档 `docs/lessons/自测答案/S1-自测答案.md`（不在本计划内）。

- [ ] **Step 1: 写讲义**，章节：
  1. 本课重点：两件事心智模型（DI + 订阅）；S0 四大痛点如何逐条谢幕（对照表：痛点 → 重构后去哪了）。
  2. 代码地图：`state/cart_controller.dart`、`state/mini_provider.dart`、五文件 diff 导读（`git diff 93abcd2 -- state_lab/lib/versions/`）。
  3. 控件/API 速查表（iOS 类比 + 坑）：InheritedWidget、dependOn/getInherited、ChangeNotifier、ValueNotifier、ListenableBuilder、`List.unmodifiable`、`Builder`（圈依赖粒度用）。
  4. 关键实验（模拟器上做）：加购一件 → 看 `列表角标` RebuildBadge +1 而卡片计数不动（对照 S0 课后练习的数字）；详情页 → 购物车清空 → 返回，角标自动清零（学员的 bug 不用补丁也好了）。
  5. 自测清单（≥8 题）：of/read 差别与各自使用时机？为什么 push 的路由要 re-provide？MiniProvider 的 Element 为什么要订阅 notifier？updateShouldNotify 日常刷新走不走？购物车页为什么能变 Stateless？依赖粒度由什么决定、怎么收窄？controller 谁负责 dispose？v0 重构后还剩哪些 setState、为什么它们该留下？
  6. 课后练习：把详情页收藏心形改成 `ValueNotifier<bool> + ValueListenableBuilder`（体验第三种通知工具），完成后 revert（保持版本纯净）。

- [ ] **Step 2: 提交**

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S1 讲义"
```

---

### Task 6: 模拟器验证与过关收尾

**Files:**
- Modify: `state_lab/docs/lessons/README.md`（学员确认后 S1 行 → `✅ 完成（日期）`）

- [ ] **Step 1: 启动模拟器验证**

```bash
cd /Users/wenbo/Desktop/WBFlutter/state_lab && env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
  FLUTTER_STORAGE_BASE_URL=https://mirrors.cloud.tencent.com/flutter \
  flutter run -d 85C08A29-994F-44BC-8BEF-C0CB6D6DBFF7
```

- [ ] **Step 2: 学员走验证清单**：① 列表加购 → 角标 +1、卡片 RebuildBadge 不动；② 详情页加购 → 本页角标即时 +1（无双重 setState）；③ 详情 → 购物车清空 → 返回详情，角标已清零（无 await 补丁）；④ 搜索页同路径；⑤ 购物车增减/滑删/合计；⑥ 下拉刷新/触底加载/防抖照旧。
- [ ] **Step 3: 学员回「确认」后**：README S1 行翻 `✅ 完成（YYYY-MM-DD）`，提交：

```bash
git -C /Users/wenbo/Desktop/WBFlutter add state_lab/
git -C /Users/wenbo/Desktop/WBFlutter commit -m "S1 收官：进度表翻牌"
```

---

## Self-Review 记录

- **规格覆盖**：设计文档 S1 行的四要素——InheritedWidget 依赖注册与 updateShouldNotify、Element 查找路径（技术文档 §4）、ChangeNotifier/ValueNotifier/ListenableBuilder（Task 1 实战 + 技术文档 §2 + 课后练习）、手写 ~40 行迷你 Provider 替换 v0 层层传参（Task 2/3）、技术文档 s1（Task 4）——全部有任务承接。✅
- **占位符扫描**：无 TBD/TODO；文档任务给到章节级内容要点与全部技术事实。✅
- **类型一致性**：`CartController.add/changeQty/remove/clear/items/isEmpty/totalCount/totalPrice`、`MiniProvider.of/read`、页面新签名在 Task 1/2/3 间已核对一致；`V0ShopRoot(api:)` 外部签名不变，既有测试可原样通过。✅
