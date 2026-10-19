import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wan_android/app/app.dart';
import 'package:wan_android/core/network/dio_client.dart';
import 'package:wan_android/core/storage/auth_storage.dart';
import 'package:wan_android/features/auth/ui.dart';
import 'package:wan_android/features/cart/data/cart_dependencies.dart';
import 'package:wan_android/features/cart/data/cart_storage.dart';
import 'package:wan_android/features/cart/models.dart';
import 'package:wan_android/features/cart/ui.dart';
import 'package:wan_android/features/categories/data/categories_dependencies.dart';
import 'package:wan_android/features/categories/data/categories_repository.dart';
import 'package:wan_android/features/categories/domain/category.dart';
import 'package:wan_android/features/orders/ui.dart';
import 'package:wan_android/features/products/data/product_list_response.dart';
import 'package:wan_android/features/products/data/products_dependencies.dart';
import 'package:wan_android/features/products/data/products_repository.dart';
import 'package:wan_android/features/products/domain/product.dart';
import 'package:wan_android/features/settings/api.dart';
import 'package:wan_android/features/settings/data/settings_dependencies.dart';

import 'i18n_support_test.dart' show MemoryLocaleStorage;
import 'support/localized_app.dart';

// M12 国际化进阶：Widget 层面的国际化测试。
// 1) App 内切换语言端到端：读偏好 → 切 ar → 整棵树变 RTL → 切回跟随系统；
// 2) "长语言 + 窄屏"冒烟：德语平均比英语长 30%，阿语要镜像，最容易出 RenderFlex overflowed。
//    测试环境里 overflow 会直接让用例失败，所以"能 pump 完不报错"本身就是断言。

class _FakeAuthStorage extends AuthStorage {
  @override
  Future<String?> readAccessToken() async => null;
}

class _FakeCategoriesRepository extends CategoriesRepository {
  _FakeCategoriesRepository() : super(dio: Dio());
  @override
  Future<List<Category>> fetchCategories() async => [];
}

class _FakeProductsRepository extends ProductsRepository {
  _FakeProductsRepository() : super(dio: Dio());
  static const _empty = ProductListResponse(
    products: [],
    total: 0,
    skip: 0,
    limit: 20,
  );
  @override
  Future<ProductListResponse> fetchProducts({int limit = 20, int skip = 0}) =>
      Future.value(_empty);
  @override
  Future<Product> fetchProduct(int id) => throw UnimplementedError();
  @override
  Future<ProductListResponse> fetchByCategory(
    String slug, {
    int limit = 30,
    int skip = 0,
  }) => Future.value(_empty);
  @override
  Future<ProductListResponse> searchProducts(
    String query, {
    int limit = 30,
    int skip = 0,
  }) => Future.value(_empty);
}

class _OneItemCartStorage extends CartStorage {
  List<CartItem> items = const [
    CartItem(
      productId: 1,
      // 故意用一个很长的商品名：验证长标题 + 长德语按钮同时出现时不溢出。
      title: 'Kabelloser Bluetooth-Kopfhörer mit aktiver Geräuschunterdrückung',
      thumbnail: '',
      unitPrice: 1234.5,
      quantity: 2,
    ),
  ];
  @override
  Future<List<CartItem>> load() async => items;
  @override
  Future<void> save(List<CartItem> value) async => items = List.of(value);
}

/// 把测试画布设成 320pt 宽的小屏（≈ iPhone SE 1 代），最容易暴露长文案溢出。
void useNarrowScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('App 内切换语言（端到端）', () {
    Future<MemoryLocaleStorage> pumpApp(
      WidgetTester tester, {
      Locale? saved,
    }) async {
      // "系统语言"设成中文：用来验证"跟随系统"分支。
      tester.platformDispatcher.localesTestValue = const [Locale('zh')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final storage = MemoryLocaleStorage(saved);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesRepositoryProvider.overrideWithValue(
              _FakeCategoriesRepository(),
            ),
            productsRepositoryProvider.overrideWithValue(
              _FakeProductsRepository(),
            ),
            authStorageProvider.overrideWithValue(_FakeAuthStorage()),
            localeStorageProvider.overrideWithValue(storage),
          ],
          child: const WanShopApp(),
        ),
      );
      await tester.pumpAndSettle();
      return storage;
    }

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(WanShopApp)));

    TextDirection directionOfTabBar(WidgetTester tester) =>
        Directionality.of(tester.element(find.byType(NavigationBar)));

    testWidgets('没选过语言 → 跟随系统（中文）', (tester) async {
      await pumpApp(tester);
      expect(find.text('首页'), findsWidgets);
      expect(directionOfTabBar(tester), TextDirection.ltr);
    });

    testWidgets('冷启动恢复上次选的德语，覆盖系统中文', (tester) async {
      await pumpApp(tester, saved: const Locale('de'));
      expect(find.text('Warenkorb'), findsWidgets);
      expect(find.text('首页'), findsNothing);
    });

    testWidgets('切到阿语：文案 + RTL 一起生效；切回跟随系统恢复中文 LTR', (tester) async {
      final storage = await pumpApp(tester);

      await containerOf(
        tester,
      ).read(appLocaleProvider.notifier).select(const Locale('ar'));
      await tester.pumpAndSettle();
      expect(find.text('الرئيسية'), findsWidgets);
      // 不用自己写任何 Directionality——Localizations 按语言自动给出 RTL。
      expect(directionOfTabBar(tester), TextDirection.rtl);
      expect(storage.persisted, const Locale('ar'));

      await containerOf(tester).read(appLocaleProvider.notifier).select(null);
      await tester.pumpAndSettle();
      expect(find.text('首页'), findsWidgets);
      expect(directionOfTabBar(tester), TextDirection.ltr);
    });
  });

  group('长语言 / RTL + 窄屏不溢出', () {
    for (final code in ['zh', 'de', 'ar']) {
      final locale = Locale(code);

      testWidgets('[$code] 整个 App 外壳（底部 4 个 Tab 标签）', (tester) async {
        useNarrowScreen(tester);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              categoriesRepositoryProvider.overrideWithValue(
                _FakeCategoriesRepository(),
              ),
              productsRepositoryProvider.overrideWithValue(
                _FakeProductsRepository(),
              ),
              authStorageProvider.overrideWithValue(_FakeAuthStorage()),
              localeStorageProvider.overrideWithValue(
                MemoryLocaleStorage(locale),
              ),
            ],
            child: const WanShopApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('[$code] 登录页', (tester) async {
        useNarrowScreen(tester);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStorageProvider.overrideWithValue(_FakeAuthStorage()),
            ],
            child: localizedApp(const LoginPage(), locale: locale),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('[$code] 购物车页（长标题 + 金额 + 去结算）', (tester) async {
        useNarrowScreen(tester);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cartStorageProvider.overrideWithValue(_OneItemCartStorage()),
            ],
            child: localizedApp(const CartPage(), locale: locale),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('[$code] 结算页（德语"Zahlungspflichtig bestellen"按钮最长）', (
        tester,
      ) async {
        useNarrowScreen(tester);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cartStorageProvider.overrideWithValue(_OneItemCartStorage()),
            ],
            child: localizedApp(const CheckoutPage(), locale: locale),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('[ar] 手机号输入框在 RTL 界面里仍是 LTR', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartStorageProvider.overrideWithValue(_OneItemCartStorage()),
          ],
          child: localizedApp(const CheckoutPage(), locale: const Locale('ar')),
        ),
      );
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .toList();
      // 收货人 / 手机号 / 地址：只有手机号被钉成 LTR，其余跟随界面方向。
      expect(fields.map((f) => f.textDirection).toList(), [
        null,
        TextDirection.ltr,
        null,
      ]);
      expect(
        Directionality.of(tester.element(find.byType(EditableText).first)),
        TextDirection.rtl,
      );
    });
  });
}
