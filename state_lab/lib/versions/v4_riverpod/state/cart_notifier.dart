import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/product.dart';

/// v4 的不可变购物车行项目/状态——与 v2 的 CartLine/CartState 蓄意重复
/// 不复用（版本自包含铁律：任何两版 diff = 纯状态管理差异）。
/// Riverpod 与 Bloc 共享"不可变状态整体替换"的世界观，样板也一样交。
class CartLine extends Equatable {
  const CartLine({required this.product, this.quantity = 1});

  final Product product;
  final int quantity;

  double get lineTotal => product.price * quantity;

  CartLine copyWith({int? quantity}) =>
      CartLine(product: product, quantity: quantity ?? this.quantity);

  @override
  List<Object?> get props => [product.id, quantity];
}

class CartState extends Equatable {
  const CartState({this.items = const []});

  final List<CartLine> items;

  bool get isEmpty => items.isEmpty;
  int get totalCount => items.fold(0, (sum, l) => sum + l.quantity);
  double get totalPrice => items.fold(0.0, (sum, l) => sum + l.lineTotal);

  @override
  List<Object?> get props => [items];
}

/// 场景③④：Notifier ≈ "Cubit 的 riverpod 版"——方法直接给 state 赋新值
/// （setter 内部同样做 == 判等短路，Equatable 又一次上岗）。
/// 与 Cubit 的差别在挂靠处：Cubit 靠 BlocProvider 挂树，Notifier 挂在
/// 树外的 provider 图上，谁 ref.watch 谁订阅。
class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void add(Product product) {
    final items = [...state.items];
    final i = items.indexWhere((l) => l.product.id == product.id);
    if (i >= 0) {
      items[i] = items[i].copyWith(quantity: items[i].quantity + 1);
    } else {
      items.add(CartLine(product: product));
    }
    state = CartState(items: items);
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
    state = CartState(items: items);
  }

  void remove(int productId) => state = CartState(
        items: state.items.where((l) => l.product.id != productId).toList(),
      );

  void clear() => state = const CartState();
}

/// 版本级共享：不带 autoDispose——只要 V4 的 ProviderScope 活着它就活着
/// （退出版本 = scope dispose = 状态清零，版本隔离由 scope 兜底）。
final cartProvider =
    NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
