// 测试 Favorites notifier + 两个派生 provider，套路完全照搬 cart_test.dart：
// ProviderContainer 直接测业务逻辑，不渲染 Widget。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wan_android/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:wan_android/features/products/domain/product.dart';

Product _makeProduct(int id) => Product(
  id: id,
  title: 'product-$id',
  description: 'desc',
  category: 'test',
  price: 100,
  discountPercentage: 0,
  rating: 4.5,
  stock: 10,
  thumbnail: 'http://x/$id.png',
  images: const [],
  tags: null,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('toggle：第一次收藏、第二次取消，派生 provider 跟着变', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(favoritesProvider.notifier);
    final p = _makeProduct(1);

    await notifier.toggle(p); // 收藏
    expect(await container.read(favoritesProvider.future), hasLength(1));
    expect(container.read(isFavoriteProvider(1)), isTrue);
    expect(container.read(favoritesCountProvider), 1);

    await notifier.toggle(p); // 再点一次 = 取消收藏
    expect(await container.read(favoritesProvider.future), isEmpty);
    expect(container.read(isFavoriteProvider(1)), isFalse);
    expect(container.read(favoritesCountProvider), 0);
  });

  test('isFavorite 只认自己的 id：收藏 1 号不影响 2 号的判定', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(favoritesProvider.notifier).toggle(_makeProduct(1));

    expect(container.read(isFavoriteProvider(1)), isTrue);
    expect(container.read(isFavoriteProvider(2)), isFalse);
  });

  test('持久化往返：新建 container 能 load 回同样的收藏（含商品快照字段）', () async {
    final container1 = ProviderContainer();
    await container1.read(favoritesProvider.notifier).toggle(_makeProduct(7));
    container1.dispose();

    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    final items = await container2.read(favoritesProvider.future);

    expect(items, hasLength(1));
    expect(items.first.id, 7);
    expect(items.first.title, 'product-7'); // 快照字段也完整存回来了
  });
}
