/// 商品模型（DummyJSON /products 字段子集，只建模课程用得到的——YAGNI）。
/// 类比 iOS：一个 Codable struct；fromJson ≈ init(from: Decoder)。
/// WanShop M2 用 json_serializable 代码生成；本工程模型极少，手写更直观。
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

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      // JSON 数字可能是 int(9) 也可能是 double(9.99)：
      // Dart 里必须先收成 num 再 toDouble（≈ OC 里 NSNumber.doubleValue），
      // 直接 as double 会在整数价格上抛 TypeError——NativeLab L2 踩过同类坑。
      price: (json['price'] as num).toDouble(),
      thumbnail: json['thumbnail'] as String,
      rating: (json['rating'] as num).toDouble(),
      brand: json['brand'] as String?, // 部分商品没有 brand 字段
    );
  }

  final int id;
  final String title;
  final String description;
  final double price;
  final String thumbnail;
  final double rating;
  final String? brand;
}

/// 一页商品（DummyJSON 的分页包裹：{products, total, skip, limit}）。
class ProductPage {
  const ProductPage({
    required this.products,
    required this.total,
    required this.skip,
    required this.limit,
  });

  factory ProductPage.fromJson(Map<String, dynamic> json) {
    return ProductPage(
      products: (json['products'] as List<dynamic>)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      skip: json['skip'] as int,
      limit: json['limit'] as int,
    );
  }

  final List<Product> products;
  final int total;
  final int skip;
  final int limit;

  /// 是否还有下一页：已取到的末尾位置 < 总数。
  bool get hasMore => skip + products.length < total;
}
