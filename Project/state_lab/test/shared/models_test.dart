import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/models/cart_item.dart';
import 'package:state_lab/shared/models/product.dart';

void main() {
  group('Product.fromJson', () {
    test('解析完整字段，int 价格也能收成 double', () {
      final p = Product.fromJson(const {
        'id': 1,
        'title': 'Essence Mascara',
        'description': 'desc',
        'price': 9, // 故意给 int：JSON 数字可能没有小数部分
        'thumbnail': 'https://example.com/1.png',
        'rating': 4.94,
        'brand': 'Essence',
      });
      expect(p.id, 1);
      expect(p.price, 9.0);
      expect(p.brand, 'Essence');
    });

    test('brand 缺失时为 null（DummyJSON 部分商品无 brand）', () {
      final p = Product.fromJson(const {
        'id': 2,
        'title': 'T',
        'description': 'd',
        'price': 5.01,
        'thumbnail': 'x',
        'rating': 4.0,
      });
      expect(p.brand, isNull);
    });
  });

  group('ProductPage', () {
    Map<String, dynamic> pageJson({required int skip, required int count}) => {
      'products': List.generate(count, (i) => {
        'id': skip + i,
        'title': 'P${skip + i}',
        'description': 'd',
        'price': 1.0,
        'thumbnail': 'x',
        'rating': 4.0,
      }),
      'total': 30,
      'skip': skip,
      'limit': 20,
    };

    test('还有下一页', () {
      final page = ProductPage.fromJson(pageJson(skip: 0, count: 20));
      expect(page.products.length, 20);
      expect(page.hasMore, isTrue);
    });

    test('已到末页', () {
      final page = ProductPage.fromJson(pageJson(skip: 20, count: 10));
      expect(page.hasMore, isFalse);
    });
  });

  test('CartItem.lineTotal = 单价 × 数量', () {
    final item = CartItem(
      product: const Product(
        id: 1, title: 'T', description: 'd', price: 9.99,
        thumbnail: 'x', rating: 4.0,
      ),
      quantity: 3,
    );
    expect(item.lineTotal, closeTo(29.97, 0.001));
  });
}
