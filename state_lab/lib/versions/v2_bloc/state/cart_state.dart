import 'package:equatable/equatable.dart';

import '../../../shared/models/product.dart';

/// v2 本地的**不可变**购物车行项目——刻意对照 shared 那个可变 CartItem。
/// S2 靠 List.unmodifiable 运行时堵门；这里是类型级根治：字段全 final，
/// 想改只能 copyWith 出一个新对象。这就是 S2 自测答案练习 2 说的
/// "copyWith 税"，换来的是值语义 == 与可判等的状态。
class CartLine extends Equatable {
  const CartLine({required this.product, this.quantity = 1});

  final Product product;
  final int quantity;

  double get lineTotal => product.price * quantity;

  CartLine copyWith({int? quantity}) =>
      CartLine(product: product, quantity: quantity ?? this.quantity);

  /// Product 没实现值 ==（json_serializable 不生成），用 id 拿值语义就够。
  @override
  List<Object?> get props => [product.id, quantity];
}

/// 购物车状态：不可变、可判等。派生值（总数/总价）仍是现算的 getter，
/// 但它们进不进 props 无所谓——props 只放 items，items 变了整体就不等。
class CartState extends Equatable {
  const CartState({this.items = const []});

  final List<CartLine> items;

  bool get isEmpty => items.isEmpty;
  int get totalCount => items.fold(0, (sum, l) => sum + l.quantity);
  double get totalPrice => items.fold(0.0, (sum, l) => sum + l.lineTotal);

  CartState copyWith({List<CartLine>? items}) =>
      CartState(items: items ?? this.items);

  @override
  List<Object?> get props => [items];
}
