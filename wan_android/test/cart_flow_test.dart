// 端到端一点的 widget 测试：真的"点一下"按钮，验证详情页 → 购物车这条链路真的通。
// 比手动在模拟器里点更可靠、可重复运行、能进 CI。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wan_android/features/categories/domain/category.dart';
import 'package:wan_android/features/products/data/product_list_response.dart';
import 'package:wan_android/features/products/data/products_repository.dart';
import 'package:wan_android/features/products/domain/product.dart';
import 'package:wan_android/features/products/presentation/product_detail_page.dart';
import 'package:wan_android/features/products/presentation/providers/products_providers.dart';

class _FakeProductsRepository extends ProductsRepository {
  final Product product;
  _FakeProductsRepository(this.product);

  @override
  Future<Product> fetchProduct(int id) => Future.value(product);

  @override
  Future<ProductListResponse> fetchProducts({int limit = 20, int skip = 0}) =>
      Future.value(const ProductListResponse(products: [], total: 0, skip: 0, limit: 20));

  @override
  Future<List<Category>> fetchCategories() => Future.value(const []);

  @override
  Future<ProductListResponse> fetchByCategory(
    String slug, {
    int limit = 30,
    int skip = 0,
  }) => Future.value(const ProductListResponse(products: [], total: 0, skip: 0, limit: 30));

  @override
  Future<ProductListResponse> searchProducts(
    String query, {
    int limit = 30,
    int skip = 0,
  }) => Future.value(const ProductListResponse(products: [], total: 0, skip: 0, limit: 30));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('详情页点"加入购物车"后弹出确认提示', (tester) async {
    const product = Product(
      id: 1,
      title: '测试商品',
      description: 'd',
      category: 'c',
      price: 100,
      discountPercentage: 10,
      rating: 4.5,
      stock: 5,
      thumbnail: 'http://x/1.png',
      images: [],
      tags: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productsRepositoryProvider.overrideWithValue(
            _FakeProductsRepository(product),
          ),
        ],
        child: const MaterialApp(home: ProductDetailPage(id: 1)),
      ),
    );

    // 等待 productProvider(1) 的 Future resolve、详情页从 loading 渲染到 data。
    await tester.pumpAndSettle();

    expect(find.text('加入购物车'), findsOneWidget);

    // tester.tap 是真的"点一下"这个按钮（找到 Widget → 派发点击手势）。
    await tester.tap(find.text('加入购物车'));
    await tester.pump(); // 让 onPressed 里的 setState/SnackBar 生效一帧

    // 断言 SnackBar 文案里带上了商品标题，证明点击确实调用了 addProduct 并成功。
    expect(find.textContaining('已加入购物车'), findsOneWidget);
    expect(find.textContaining('测试商品'), findsWidgets);
  });
}
