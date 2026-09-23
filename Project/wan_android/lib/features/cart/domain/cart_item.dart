import 'package:json_annotation/json_annotation.dart';

part 'cart_item.g.dart';

/// 购物车里的一行。
///
/// 注意：这里不直接存整个 Product，而是存"加入购物车那一刻的快照"
/// （标题、缩略图、单价、数量）。这是电商购物车的标准做法——
/// 即使后续商品改价/下架，购物车里已加入的行情不受影响，
/// ≈ 你下单快照表的设计思路，而不是实时引用商品表。
@JsonSerializable()
class CartItem {
  final int productId;
  final String title;
  final String thumbnail;
  final double unitPrice; // 加入时的单价（用折后价）
  final int quantity;

  const CartItem({
    required this.productId,
    required this.title,
    required this.thumbnail,
    required this.unitPrice,
    required this.quantity,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) =>
      _$CartItemFromJson(json);
  Map<String, dynamic> toJson() => _$CartItemToJson(this);

  double get subtotal => unitPrice * quantity;

  /// 返回一个"数量不同"的新副本。
  /// Dart 对象默认不可变（这里字段都是 final），改数量要靠 copyWith 造一个新对象，
  /// ≈ Swift struct 的值语义修改（let 一份新的，而不是就地改）。
  CartItem copyWith({int? quantity}) => CartItem(
    productId: productId,
    title: title,
    thumbnail: thumbnail,
    unitPrice: unitPrice,
    quantity: quantity ?? this.quantity,
  );
}
