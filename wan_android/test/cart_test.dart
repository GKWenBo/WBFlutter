// 测试 CartNotifier ≈ 给你的 CartViewModel 写 XCTest。
// 用 ProviderContainer 而不是渲染 Widget——直接测业务逻辑，跑得快、不依赖 UI。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wan_android/features/cart/presentation/providers/cart_providers.dart';
import 'package:wan_android/features/products/domain/product.dart';

Product _makeProduct(int id, {double price = 100, double discount = 0}) =>
    Product(
      id: id,
      title: 'product-$id',
      description: 'desc',
      category: 'test',
      price: price,
      discountPercentage: discount,
      rating: 4.5,
      stock: 10,
      thumbnail: 'http://x/$id.png',
      images: const [],
      tags: null,
    );

void main() {
  // shared_preferences 在测试环境里没有真实系统存储，
  // 用 setMockInitialValues 给一份内存假实现（≈ 给 UserDefaults 打 mock）。
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('addProduct 同款商品累加数量，总件数/总价随之派生', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(cartProvider.notifier);
    final p1 = _makeProduct(1, price: 100, discount: 10); // discountedPrice = 90
    await notifier.addProduct(p1);
    await notifier.addProduct(p1); // 再加一次同款 → 数量叠加，不是新增一行

    // cartProvider.future：等待并拿到"当前已确定的最新值"（不是初始 build 的值）。
    final items = await container.read(cartProvider.future);
    expect(items.length, 1);
    expect(items.first.quantity, 2);
    expect(container.read(cartTotalCountProvider), 2);
    expect(container.read(cartTotalPriceProvider), closeTo(180, 0.001));
  });

  test('updateQuantity 降到 0 会移除该行', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(cartProvider.notifier);
    await notifier.addProduct(_makeProduct(2));
    await notifier.updateQuantity(2, 0);

    final items = await container.read(cartProvider.future);
    expect(items, isEmpty);
    expect(container.read(cartTotalCountProvider), 0);
  });

  test('removeItem 只移除指定商品，其它行不受影响', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(cartProvider.notifier);
    await notifier.addProduct(_makeProduct(1));
    await notifier.addProduct(_makeProduct(2));
    await notifier.removeItem(1);

    final items = await container.read(cartProvider.future);
    expect(items.length, 1);
    expect(items.first.productId, 2);
  });

  test('持久化往返：save 后新建 container 能重新 load 回同样数据', () async {
    final container1 = ProviderContainer();
    await container1
        .read(cartProvider.notifier)
        .addProduct(_makeProduct(3, price: 50));
    container1.dispose();

    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    final items = await container2.read(cartProvider.future);

    expect(items.length, 1);
    expect(items.first.productId, 3);
    expect(items.first.unitPrice, 50.0);
  });
}
