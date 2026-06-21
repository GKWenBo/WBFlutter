import 'package:json_annotation/json_annotation.dart';

// part 指令：把"同名 + .g.dart"的生成文件拼接进本文件。
// 里面的 _$ProductFromJson / _$ProductToJson 由 build_runner 自动生成。
// 写完这一行先别管报红，等跑完代码生成就有了。
part 'product.g.dart';

/// 商品模型 ≈ 你 iOS 里的 Codable struct。
///
/// 字段对照 DummyJSON `/products` 接口返回的结构（M3 会真正去请求它）。
/// 加 @JsonSerializable() 后，fromJson/toJson 的样板代码交给代码生成，
/// 你只维护字段——这就是 Dart 版的 Codable。
@JsonSerializable()
class Product {
  final int id;
  final String title;
  final String description;
  final String category;
  final double price;
  final double discountPercentage;
  final double rating;
  final int stock;

  // 可空字段 ≈ Swift 的 Optional（String?）。DummyJSON 有些商品没有 brand。
  final String? brand;

  final String thumbnail; // 列表缩略图
  final List<String> images; // 详情多图

  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.discountPercentage,
    required this.rating,
    required this.stock,
    this.brand,
    required this.thumbnail,
    required this.images,
  });

  /// JSON → 对象。≈ Swift `JSONDecoder().decode(Product.self, from:)`。
  /// 实现体 _$ProductFromJson 由代码生成提供。
  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);

  /// 对象 → JSON。≈ Swift `JSONEncoder().encode(product)`。
  Map<String, dynamic> toJson() => _$ProductToJson(this);

  /// 业务计算属性：折后价。
  /// 把"派生数据"作为 getter 放在 model 上，≈ Swift 给 struct 加 computed property / extension。
  double get discountedPrice => price * (1 - discountPercentage / 100);
}
