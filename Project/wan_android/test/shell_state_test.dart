import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wan_android/app/app.dart';
import 'package:wan_android/core/network/dio_client.dart';
import 'package:wan_android/core/storage/auth_storage.dart';
import 'package:wan_android/features/categories/data/categories_dependencies.dart';
import 'package:wan_android/features/categories/data/categories_repository.dart';
import 'package:wan_android/features/categories/models.dart';
import 'package:wan_android/features/products/data/product_list_response.dart';
import 'package:wan_android/features/products/data/products_dependencies.dart';
import 'package:wan_android/features/products/data/products_repository.dart';
import 'package:wan_android/features/products/models.dart';
import 'package:wan_android/features/products/ui.dart';

class AnonymousStorage extends AuthStorage {
  @override
  Future<String?> readAccessToken() async => null;
}

class CategoriesFixture extends CategoriesRepository {
  CategoriesFixture() : super(dio: Dio());
  @override
  Future<List<Category>> fetchCategories() async => [];
}

class ProductsFixture extends ProductsRepository {
  ProductsFixture() : super(dio: Dio());
  @override
  Future<ProductListResponse> fetchProducts({
    int limit = 20,
    int skip = 0,
  }) async => ProductListResponse(
    products: List.generate(
      20,
      (id) => Product(
        id: id,
        title: '商品$id',
        description: '',
        category: '',
        price: 10,
        discountPercentage: 0,
        rating: 4,
        stock: 10,
        thumbnail: 'http://x/$id.png',
        images: [],
        tags: null,
      ),
    ),
    total: 20,
    skip: 0,
    limit: 20,
  );
}

void main() {
  testWidgets('Tab 切换保留首页滚动位置', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.localesTestValue = const [Locale('zh')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStorageProvider.overrideWithValue(AnonymousStorage()),
          productsRepositoryProvider.overrideWithValue(ProductsFixture()),
          categoriesRepositoryProvider.overrideWithValue(CategoriesFixture()),
        ],
        child: const WanShopApp(),
      ),
    );
    // 商品图片占位有持续动画；本测试只等待页面构建与切换动画，不等待图片 I/O。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final scroll = tester.widget<CustomScrollView>(
      find.descendant(
        of: find.byType(HomePage),
        matching: find.byType(CustomScrollView),
      ),
    );
    scroll.controller!.jumpTo(400);
    await tester.pump();
    await tester.tap(find.text('分类').last);
    // 商品图片占位有持续动画；本测试只等待页面构建与切换动画，不等待图片 I/O。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('首页').last);
    // 商品图片占位有持续动画；本测试只等待页面构建与切换动画，不等待图片 I/O。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final restored = tester.widget<CustomScrollView>(
      find.descendant(
        of: find.byType(HomePage),
        matching: find.byType(CustomScrollView),
      ),
    );
    expect(identical(restored.controller, scroll.controller), isTrue);
    expect(restored.controller!.offset, 400);
  });
}
