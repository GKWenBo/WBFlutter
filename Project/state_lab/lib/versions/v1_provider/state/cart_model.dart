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
