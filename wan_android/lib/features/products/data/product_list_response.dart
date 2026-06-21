import 'package:json_annotation/json_annotation.dart';

import '../domain/product.dart';

part 'product_list_response.g.dart';

/// DummyJSON `/products` 接口返回的"分页信封"：
/// ```json
/// { "products": [ {...}, ... ], "total": 194, "skip": 0, "limit": 20 }
/// ```
/// 代码生成会自动识别 products 是 `List<Product>` 并对每个元素调用 Product.fromJson
/// （嵌套对象的解析它会帮你串好，≈ Codable 自动递归解码）。
@JsonSerializable()
class ProductListResponse {
  final List<Product> products;
  final int total; // 总条数（用于判断还有没有下一页）
  final int skip; // 本次跳过了多少条
  final int limit; // 本次取了多少条

  const ProductListResponse({
    required this.products,
    required this.total,
    required this.skip,
    required this.limit,
  });

  factory ProductListResponse.fromJson(Map<String, dynamic> json) =>
      _$ProductListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ProductListResponseToJson(this);

  /// 是否还有下一页（M4 上拉加载更多要用）。
  bool get hasMore => skip + products.length < total;
}
