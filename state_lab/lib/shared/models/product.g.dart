// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  description: json['description'] as String,
  price: (json['price'] as num).toDouble(),
  thumbnail: json['thumbnail'] as String,
  rating: (json['rating'] as num).toDouble(),
  brand: json['brand'] as String?,
);

ProductPage _$ProductPageFromJson(Map<String, dynamic> json) => ProductPage(
  products: (json['products'] as List<dynamic>)
      .map((e) => Product.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
  skip: (json['skip'] as num).toInt(),
  limit: (json['limit'] as num).toInt(),
);
