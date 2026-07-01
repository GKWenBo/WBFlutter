// Widget 测试 ≈ iOS 的 XCUITest，但快得多：不启模拟器，在内存里渲染 Widget 树后断言。
// 这里先放一个最小冒烟测试：App 能正常构建，且底部 4 个 Tab 标签都在。
// （M11 会专门讲 unit / widget / integration 三层测试。）

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wan_android/app/app.dart';
import 'package:wan_android/features/categories/domain/category.dart';
import 'package:wan_android/features/products/data/product_list_response.dart';
import 'package:wan_android/features/products/data/products_repository.dart';
import 'package:wan_android/features/products/domain/product.dart';
import 'package:wan_android/features/products/presentation/providers/products_providers.dart';

/// 假的 Repository：widget 测试不该碰真实网络。
/// 继承 ProductsRepository 并把每个方法都换成"立即返回空数据"，
/// ≈ 你在 XCTest 里注入一个 mock Service，而不是真的打网络请求。
class _FakeProductsRepository extends ProductsRepository {
  @override
  Future<ProductListResponse> fetchProducts({int limit = 20, int skip = 0}) =>
      Future.value(const ProductListResponse(products: [], total: 0, skip: 0, limit: 20));

  @override
  Future<Product> fetchProduct(int id) => throw UnimplementedError();

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
  // Cart provider 会读 shared_preferences，测试环境没有真实系统存储，
  // 用 setMockInitialValues 给一份内存假实现（≈ 给 UserDefaults 打 mock）。
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App 启动后底部 4 个 Tab 都存在', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // 用 overrideWithValue 把真实 Repository 换成假的——
        // 这样 widget 测试完全不碰真实网络，跑得快也不会有残留请求把测试判失败。
        overrides: [
          productsRepositoryProvider.overrideWithValue(_FakeProductsRepository()),
        ],
        child: const WanShopApp(),
      ),
    );

    // 底部导航的 4 个标签应该都能找到。
    // 用 findsWidgets（≥1）而非 findsOneWidget：因为 IndexedStack 会把所有 Tab 页面都构建出来，
    // 文案可能在多处出现。
    expect(find.text('首页'), findsWidgets);
    expect(find.text('分类'), findsWidgets);
    expect(find.text('购物车'), findsWidgets);
    expect(find.text('我的'), findsWidgets);
  });
}
