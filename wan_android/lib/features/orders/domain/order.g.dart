// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderItem _$OrderItemFromJson(Map<String, dynamic> json) => OrderItem(
  productId: (json['productId'] as num).toInt(),
  title: json['title'] as String,
  thumbnail: json['thumbnail'] as String,
  unitPrice: (json['unitPrice'] as num).toDouble(),
  quantity: (json['quantity'] as num).toInt(),
);

Map<String, dynamic> _$OrderItemToJson(OrderItem instance) => <String, dynamic>{
  'productId': instance.productId,
  'title': instance.title,
  'thumbnail': instance.thumbnail,
  'unitPrice': instance.unitPrice,
  'quantity': instance.quantity,
};

ShippingAddress _$ShippingAddressFromJson(Map<String, dynamic> json) =>
    ShippingAddress(
      name: json['name'] as String,
      phone: json['phone'] as String,
      detail: json['detail'] as String,
    );

Map<String, dynamic> _$ShippingAddressToJson(ShippingAddress instance) =>
    <String, dynamic>{
      'name': instance.name,
      'phone': instance.phone,
      'detail': instance.detail,
    };

Order _$OrderFromJson(Map<String, dynamic> json) => Order(
  id: json['id'] as String,
  items: (json['items'] as List<dynamic>)
      .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  address: ShippingAddress.fromJson(json['address'] as Map<String, dynamic>),
  totalPrice: (json['totalPrice'] as num).toDouble(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  status: $enumDecode(_$OrderStatusEnumMap, json['status']),
);

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
  'id': instance.id,
  'items': instance.items.map((e) => e.toJson()).toList(),
  'address': instance.address.toJson(),
  'totalPrice': instance.totalPrice,
  'createdAt': instance.createdAt.toIso8601String(),
  'status': _$OrderStatusEnumMap[instance.status]!,
};

const _$OrderStatusEnumMap = {
  OrderStatus.submitted: 'submitted',
  OrderStatus.paid: 'paid',
  OrderStatus.shipped: 'shipped',
};
