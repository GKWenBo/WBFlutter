import 'package:flutter/material.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/cart_item.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../../../shared/widgets/product_card.dart';
import '../../../shared/widgets/rebuild_badge.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';
import 'search_page.dart';

/// 场景①：异步三态 + 分页（页面私有状态，setState 的舒适区）。
/// ⭐ 痛点展品 1：本页自己只用 api / cart / onAddToCart，
/// 但 onChangeQty / onRemoveItem / onClearCart 也得原样过一遍手——
/// 因为更深处的购物车页需要。纯纯的"快递中转站"。
class V0ProductListPage extends StatefulWidget {
  const V0ProductListPage({
    super.key,
    required this.api,
    required this.cart,
    required this.onAddToCart,
    required this.onChangeQty,
    required this.onRemoveItem,
    required this.onClearCart,
  });

  final ProductApi api;
  final List<CartItem> cart;
  final ValueChanged<Product> onAddToCart;
  final void Function(int productId, int delta) onChangeQty;
  final ValueChanged<int> onRemoveItem;
  final VoidCallback onClearCart;

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

  /// 场景④的雏形：角标数量是**派生值**，每次 build 现算，绝不单独存一份。
  int get _cartCount => widget.cart.fold(0, (sum, it) => sum + it.quantity);

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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => V0CartPage(
          cart: widget.cart,
          onChangeQty: widget.onChangeQty,
          onRemoveItem: widget.onRemoveItem,
          onClearCart: widget.onClearCart,
        ),
      ),
    );
  }

  void _openDetail(Product product) {
    // ⭐ 痛点展品 1 现场：进个详情页要手递 6 个参数。
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => V0ProductDetailPage(
          product: product,
          cart: widget.cart,
          onAddToCart: widget.onAddToCart,
          onChangeQty: widget.onChangeQty,
          onRemoveItem: widget.onRemoveItem,
          onClearCart: widget.onClearCart,
        ),
      ),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => V0SearchPage(
          api: widget.api,
          cart: widget.cart,
          onAddToCart: widget.onAddToCart,
          onChangeQty: widget.onChangeQty,
          onRemoveItem: widget.onRemoveItem,
          onClearCart: widget.onClearCart,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniShop · v0 setState'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: _openSearch,
          ),
          // 本页在状态根的子树里：根 setState 会带着它重建，角标"自动"新。
          // （对照 detail/cart 页就没这待遇——见各页注释。）
          RebuildBadge(
            label: '列表角标',
            child: CartIconButton(count: _cartCount, onPressed: _openCart),
          ),
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
                    widget.onAddToCart(product);
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
