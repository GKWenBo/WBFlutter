import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wan_android/core/storage/json_preferences_store.dart';
import 'package:wan_android/features/cart/data/cart_storage.dart';
import 'package:wan_android/features/products/data/products_cache.dart';

class MockPreferences extends Mock implements SharedPreferences {}

class BrokenStore extends JsonPreferencesStore {
  @override
  Future<Object?> read(String key) async => throw StateError('读取失败');
  @override
  Future<void> write(String key, Object value) async =>
      throw StateError('写入失败');
}

void main() {
  test('底层返回 false 也视为保存失败', () async {
    final prefs = MockPreferences();
    when(() => prefs.setString(any(), any())).thenAnswer((_) async => false);
    final store = JsonPreferencesStore(preferences: () async => prefs);
    await expectLater(store.write('key', []), throwsStateError);
  });
  test('主数据损坏不降级为空列表', () async {
    SharedPreferences.setMockInitialValues({'cart_items': '{broken'});
    await expectLater(CartStorage().load(), throwsFormatException);
  });
  test('缓存读取和写入失败不向外传播', () async {
    final cache = ProductsCache(store: BrokenStore());
    expect(await cache.load(), isNull);
    await cache.save([]);
  });
}
