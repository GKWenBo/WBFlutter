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
