import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wan_android/core/error/failure.dart';
import 'package:wan_android/core/network/dio_client.dart';
import 'package:wan_android/core/storage/auth_storage.dart';
import 'package:wan_android/features/products/data/product_list_response.dart';
import 'package:wan_android/features/products/data/products_dependencies.dart';
import 'package:wan_android/features/products/data/products_repository.dart';
import 'package:wan_android/features/products/ui.dart';
import 'package:wan_android/features/profile/ui.dart';

class BrokenLogoutStorage extends AuthStorage {
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<void> clear() async => throw StateError('删除凭证失败');
}

class OfflineRepository extends ProductsRepository {
  OfflineRepository() : super(dio: Dio());
  @override
  Future<ProductListResponse> fetchProducts({
    int limit = 20,
    int skip = 0,
  }) async => throw const NetworkException('断网');
}

void main() {
  testWidgets('登出失败有提示，不产生未处理异常', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStorageProvider.overrideWithValue(BrokenLogoutStorage()),
        ],
        child: const MaterialApp(home: ProfilePage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    expect(find.textContaining('操作失败'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('刷新失败通过错误态展示，刷新回调正常结束', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          productsRepositoryProvider.overrideWithValue(OfflineRepository()),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await expectLater(indicator.onRefresh(), completes);
    await tester.pumpAndSettle();
    expect(find.textContaining('断网'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
