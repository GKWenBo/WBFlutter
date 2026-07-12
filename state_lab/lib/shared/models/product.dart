import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart'; // 生成物：build_runner 产出的 _$ProductFromJson 等就住在这

/// 商品模型（DummyJSON /products 字段子集，只建模课程用得到的——YAGNI）。
/// 类比 iOS：Codable struct——你只声明字段，编解码由编译器/工具合成。
/// Dart 没有宏反射，靠 build_runner 代码生成（产出 product.g.dart），
/// 效果等同 Swift 编译器自动合成 init(from: Decoder)。
@JsonSerializable(createToJson: false) // 本课只收包不发包，不生成 toJson
class Product {
  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.thumbnail,
    required this.rating,
    this.brand,
  });

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);

  final int id;
  final String title;
  final String description;

  /// 字段声明为 double，生成器自动做 (as num).toDouble()——
  /// JSON 里 int(9)/double(9.99) 都接得住，手写时代最易踩的坑由框架兜底。
  final double price;
  final String thumbnail;
  final double rating;
  final String? brand; // 可空字段：部分商品没有 brand，生成器按 String? 处理
}

/// 一页商品（DummyJSON 的分页包裹：{products, total, skip, limit}）。
@JsonSerializable(createToJson: false)
class ProductPage {
  const ProductPage({
    required this.products,
    required this.total,
    required this.skip,
    required this.limit,
  });

  /// 嵌套模型：生成器看到 `List<Product>` 会自动逐项调 Product.fromJson。
  factory ProductPage.fromJson(Map<String, dynamic> json) =>
      _$ProductPageFromJson(json);

  final List<Product> products;
  final int total;
  final int skip;
  final int limit;

  /// 是否还有下一页：已取到的末尾位置 < 总数。
  /// 派生状态用 getter 现算（场景④原则），不进 JSON 也不落地存储。
  bool get hasMore => skip + products.length < total;
}
