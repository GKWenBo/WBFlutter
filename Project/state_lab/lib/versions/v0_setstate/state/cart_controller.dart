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
