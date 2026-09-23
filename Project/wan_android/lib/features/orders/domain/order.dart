import 'package:json_annotation/json_annotation.dart';

import '../../cart/domain/cart_item.dart';

part 'order.g.dart';

/// 订单状态：Dart 的**增强枚举**（enhanced enum）——枚举也能带字段和构造函数，
/// ≈ Swift enum 的 rawValue / 计算属性，比"枚举 + 散落在 UI 里的 switch 转文案"干净。
/// @JsonValue 指定序列化时存的字符串（存 'submitted' 而不是下标 0——
/// 存下标的话以后往枚举中间插一个新状态，老数据全部错位）。
enum OrderStatus {
  @JsonValue('submitted')
  submitted('已提交'),
  @JsonValue('paid')
  paid('已支付'),
  @JsonValue('shipped')
  shipped('已发货');

  final String label; // 给 UI 显示的中文文案
  const OrderStatus(this.label);
}

/// 订单行 = "快照的快照"。
///
/// 为什么不直接复用 CartItem？语义不同：购物车行是**可变的**（数量随时改、行随时删），
/// 订单行是**下单那一刻的永久冻结**，之后购物车怎么变都不影响它。
/// 用独立类型把"这个数据不会再变"写进类型系统（≈ 你在 iOS 里区分草稿模型和落库模型）。
/// fromCartItem 工厂负责"冻结"这一步——orders 单向依赖 cart（cart 永远不 import orders）。
@JsonSerializable()
class OrderItem {
  final int productId;
  final String title;
  final String thumbnail;
  final double unitPrice;
  final int quantity;

  const OrderItem({
    required this.productId,
    required this.title,
    required this.thumbnail,
    required this.unitPrice,
    required this.quantity,
  });

  /// 把购物车行冻结成订单行。
  factory OrderItem.fromCartItem(CartItem item) => OrderItem(
    productId: item.productId,
    title: item.title,
    thumbnail: item.thumbnail,
    unitPrice: item.unitPrice,
    quantity: item.quantity,
  );

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
  Map<String, dynamic> toJson() => _$OrderItemToJson(this);

  double get subtotal => unitPrice * quantity;
}

/// 收货地址。M10 里它随订单一起存（订单要记住"当时寄到哪"），
/// 同时最近一次填写的会单独存一份作为"默认地址"，下次结算自动带出。
@JsonSerializable()
class ShippingAddress {
  final String name; // 收货人
  final String phone; // 手机号
  final String detail; // 详细地址（教学从简：不拆省市区三级联动）

  const ShippingAddress({
    required this.name,
    required this.phone,
    required this.detail,
  });

  factory ShippingAddress.fromJson(Map<String, dynamic> json) =>
      _$ShippingAddressFromJson(json);
  Map<String, dynamic> toJson() => _$ShippingAddressToJson(this);
}

/// 订单。M10 是 mock 闭环：DummyJSON 没有真的下单接口，
/// 订单本地生成、本地持久化——但模型/分层/流程都按真实项目的样子搭，
/// 以后接真后端只需要把"生成订单"换成"POST /orders 拿回单号"。
///
/// explicitToJson: true 是嵌套对象的坑：默认 toJson 只做浅转换，
/// items/address 字段会原样留着对象引用；开了它才会递归调用每个子对象的 toJson。
/// （jsonEncode 兜底也能救回来，但别赌运气——写进注解里最明确。）
@JsonSerializable(explicitToJson: true)
class Order {
  final String id; // 本地生成的单号（时间戳），接真后端后换成服务端返回的
  final List<OrderItem> items;
  final ShippingAddress address;
  final double totalPrice;
  final DateTime createdAt; // json_serializable 自动转 ISO8601 字符串
  final OrderStatus status;

  const Order({
    required this.id,
    required this.items,
    required this.address,
    required this.totalPrice,
    required this.createdAt,
    required this.status,
  });

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
  Map<String, dynamic> toJson() => _$OrderToJson(this);

  /// 订单总件数（列表页显示"共 N 件"）。
  int get totalCount => items.fold(0, (sum, e) => sum + e.quantity);
}
