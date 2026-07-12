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
