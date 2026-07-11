import 'package:flutter/material.dart';

import '../../shared/api/dio_client.dart';
import '../../shared/api/product_api.dart';
import '../../shared/models/cart_item.dart';
import '../../shared/models/product.dart';
import 'pages/product_list_page.dart';

/// v0 的「状态根」：整个 v0 子树的共享状态（购物车）都活在这个 State 里。
/// 类比 iOS：一个持有数据的根 VC，把数据 + delegate 回调一层层手递给子 VC
/// （prepareForSegue 时代的写法）。这就是 setState 跨页共享的原始形态。
class V0ShopRoot extends StatefulWidget {
  const V0ShopRoot({super.key, this.api});

  /// 可注入的 API（测试传 Fake；生产走 DummyJSON）。
  final ProductApi? api;

  @override
  State<V0ShopRoot> createState() => _V0ShopRootState();
}

class _V0ShopRootState extends State<V0ShopRoot> {
  late final ProductApi _api = widget.api ?? ProductApi(buildDio());

  /// 购物车数据本体。传给子页面的是**同一个可变 List 引用**：
  /// 谁拿到都能读到最新值，但值变了 Flutter 不会通知任何人——
  /// "通知谁重建"全靠下面这些回调里的 setState 手动兜。
  final List<CartItem> _cart = [];

  void _addToCart(Product product) {
    setState(() {
      final index = _cart.indexWhere((it) => it.product.id == product.id);
      if (index >= 0) {
        _cart[index].quantity += 1;
      } else {
        _cart.add(CartItem(product: product));
      }
    });
  }

  /// 数量增减；减到 0 自动移除。
  void _changeQty(int productId, int delta) {
    setState(() {
      final index = _cart.indexWhere((it) => it.product.id == productId);
      if (index < 0) return;
      _cart[index].quantity += delta;
      if (_cart[index].quantity <= 0) _cart.removeAt(index);
    });
  }

  void _removeItem(int productId) {
    setState(() => _cart.removeWhere((it) => it.product.id == productId));
  }

  void _clearCart() {
    setState(() => _cart.clear());
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ 这里的 setState 只能重建**这棵子树**（也就是列表页）。
    // detail/cart/search 是 push 到 MaterialApp 的 Navigator 上的兄弟路由，
    // 不在这棵子树里——它们改完购物车得自己 setState 刷新自己（双重 setState）。
    // 这就是 v0 最大的痛，S1 的 InheritedWidget 就是冲它来的。
    return V0ProductListPage(
      api: _api,
      cart: _cart,
      onAddToCart: _addToCart,
      onChangeQty: _changeQty,
      onRemoveItem: _removeItem,
      onClearCart: _clearCart,
    );
  }
}
