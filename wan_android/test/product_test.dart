// 纯 Dart 单元测试 ≈ iOS 的 XCTest。不启模拟器，直接验证逻辑，毫秒级。
// 这里验证 Product 的 JSON 解析（≈ 测你的 Codable 解码）。

import 'package:flutter_test/flutter_test.dart';
import 'package:wan_android/features/products/data/sample_products.dart';
import 'package:wan_android/features/products/domain/product.dart';

void main() {
  test('Product.fromJson 正确解析字段（含 int→double、可空、计算属性）', () {
    final json = <String, dynamic>{
      'id': 1,
      'title': '测试商品',
      'description': '描述',
      'category': 'test',
      'price': 100, // 故意写成 int，验证代码生成的 num→double 转换
      'discountPercentage': 10,
      'rating': 4.5,
      'stock': 3,
      'brand': null, // 可空字段 ≈ Optional
      'thumbnail': 'http://x/t.png',
      'images': ['http://x/1.png'],
    };

    final p = Product.fromJson(json);

    expect(p.id, 1);
    expect(p.price, 100.0); // int 100 被安全转成 double 100.0
    expect(p.brand, isNull);
    expect(p.images.length, 1);
    // 折后价 = 100 * (1 - 10/100) = 90
    expect(p.discountedPrice, closeTo(90.0, 0.001));
  });

  test('sampleProducts 能解析出 6 条商品', () {
    final list = sampleProducts();
    expect(list.length, 6);
    expect(list.first.title, contains('iPhone'));
  });
}
