import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/cart_item.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../../../shared/widgets/product_card.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';

/// 场景⑤：输入流处理——防抖 400ms + 丢弃过期响应。
/// 类比 iOS：Combine 的 .debounce + switchToLatest / RxSwift 的
/// debounce + flatMapLatest。v0 没有流，只能 Timer + 序号手搓。
class V0SearchPage extends StatefulWidget {
  const V0SearchPage({
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

  int get _cartCount => widget.cart.fold(0, (sum, it) => sum + it.quantity);

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

  Future<void> _openCart() async {
    // 同详情页的痛点展品 3：pop 回来必须手动补 setState，角标才会跟上。
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => V0CartPage(
        cart: widget.cart,
        onChangeQty: widget.onChangeQty,
        onRemoveItem: widget.onRemoveItem,
        onClearCart: widget.onClearCart,
      ),
    ));
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openDetail(Product product) async {
    // 详情页里也能加购/清空——回来同样要补刷（一处漏 = 一处陈旧 UI）。
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => V0ProductDetailPage(
        product: product,
        cart: widget.cart,
        onAddToCart: widget.onAddToCart,
        onChangeQty: widget.onChangeQty,
        onRemoveItem: widget.onRemoveItem,
        onClearCart: widget.onClearCart,
      ),
    ));
    if (!mounted) return;
    setState(() {});
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
        actions: [CartIconButton(count: _cartCount, onPressed: _openCart)],
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
                            widget.onAddToCart(product);
                            setState(() {}); // 双重 setState：本页角标
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
