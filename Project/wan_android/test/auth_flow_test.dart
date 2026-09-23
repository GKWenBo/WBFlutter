// 端到端一点的 widget 测试：真的"点一下"底部"我的" Tab、填表单、点登录、点登出，
// 验证 go_router 的 redirect + refreshListenable 真的接对了。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wan_android/app/app.dart';
import 'package:wan_android/core/storage/auth_storage.dart';
import 'package:wan_android/features/auth/data/auth_repository.dart';
import 'package:wan_android/features/auth/data/login_response.dart';
import 'package:wan_android/features/auth/domain/user.dart';
import 'package:wan_android/features/auth/presentation/providers/auth_providers.dart';
import 'package:wan_android/features/categories/domain/category.dart';
import 'package:wan_android/features/products/data/product_list_response.dart';
import 'package:wan_android/features/products/data/products_repository.dart';
import 'package:wan_android/features/products/domain/product.dart';
import 'package:wan_android/features/products/presentation/providers/products_providers.dart';

class _FakeProductsRepository extends ProductsRepository {
  @override
  Future<ProductListResponse> fetchProducts({int limit = 20, int skip = 0}) =>
      Future.value(
        const ProductListResponse(products: [], total: 0, skip: 0, limit: 20),
      );

  @override
  Future<Product> fetchProduct(int id) => throw UnimplementedError();

  @override
  Future<List<Category>> fetchCategories() => Future.value(const []);

  @override
  Future<ProductListResponse> fetchByCategory(
    String slug, {
    int limit = 30,
    int skip = 0,
  }) => Future.value(
    const ProductListResponse(products: [], total: 0, skip: 0, limit: 30),
  );

  @override
  Future<ProductListResponse> searchProducts(
    String query, {
    int limit = 30,
    int skip = 0,
  }) => Future.value(
    const ProductListResponse(products: [], total: 0, skip: 0, limit: 30),
  );
}

class _FakeAuthStorage extends AuthStorage {
  String? token;

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    token = accessToken;
  }

  @override
  Future<void> clear() async => token = null;
}

class _FakeAuthRepository extends AuthRepository {
  @override
  Future<LoginResponse> login(String username, String password) async {
    if (username == 'emilys' && password == 'emilyspass') {
      return const LoginResponse(
        id: 1,
        username: 'emilys',
        email: 'emily.johnson@x.dummyjson.com',
        firstName: 'Emily',
        lastName: 'Johnson',
        image: 'http://x/emilys.png',
        accessToken: 'fake-access-token',
        refreshToken: 'fake-refresh-token',
      );
    }
    throw Exception('用户名或密码错误');
  }

  @override
  Future<User> fetchCurrentUser() async => const User(
    id: 1,
    username: 'emilys',
    email: 'emily.johnson@x.dummyjson.com',
    firstName: 'Emily',
    lastName: 'Johnson',
    image: 'http://x/emilys.png',
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('未登录点"我的"被拦到登录页；登录成功看到用户信息；登出后再次被拦截', (
    tester,
  ) async {
    // M12：底部 Tab 标签已国际化，测试默认 en 会渲染成英文。
    // 强制中文，让下面按"我的"文案定位 Tab 仍成立。
    tester.platformDispatcher.localesTestValue = const [Locale('zh')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productsRepositoryProvider.overrideWithValue(
            _FakeProductsRepository(),
          ),
          authStorageProvider.overrideWithValue(_FakeAuthStorage()),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const WanShopApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 未登录状态下点底部"我的" Tab：redirect 应该把我们送到登录页，而不是"我的"页。
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '登录'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));

    // 表单默认已预填测试账号，直接点登录。
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    // 登录成功后落到"我的"页，能看到用户全名。
    expect(find.text('Emily Johnson'), findsOneWidget);

    // 点登出：不发生任何显式导航，但 refreshListenable 应该让 go_router
    // 主动重新检查 redirect，把我们送回登录页。
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '登录'), findsOneWidget);
  });
}
