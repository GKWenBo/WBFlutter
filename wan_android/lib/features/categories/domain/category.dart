import 'package:json_annotation/json_annotation.dart';

part 'category.g.dart';

/// 商品分类模型 ≈ Codable struct。
/// 对应 DummyJSON `/products/categories` 返回的每个元素：
/// `{ "slug": "beauty", "name": "Beauty", "url": "https://dummyjson.com/products/category/beauty" }`
@JsonSerializable()
class Category {
  final String slug; // 用于请求该分类商品的 key（/products/category/{slug}）
  final String name; // 展示名
  final String url; // 该分类的接口地址（这里用不到，但忠实建模）

  const Category({required this.slug, required this.name, required this.url});

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryToJson(this);
}
