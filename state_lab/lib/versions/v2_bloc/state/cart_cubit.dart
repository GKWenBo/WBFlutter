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
        CartState(
          items: state.items.where((l) => l.product.id != productId).toList(),
        ),
      );

  void clear() => emit(const CartState());
}
