// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CartItem _$CartItemFromJson(Map<String, dynamic> json) => CartItem(
  productId: (json['productId'] as num).toInt(),
  title: json['title'] as String,
  thumbnail: json['thumbnail'] as String,
  unitPrice: (json['unitPrice'] as num).toDouble(),
  quantity: (json['quantity'] as num).toInt(),
);

Map<String, dynamic> _$CartItemToJson(CartItem instance) => <String, dynamic>{
  'productId': instance.productId,
  'title': instance.title,
  'thumbnail': instance.thumbnail,
  'unitPrice': instance.unitPrice,
  'quantity': instance.quantity,
};
