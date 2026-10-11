import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wan_android/features/cart/data/cart_dependencies.dart';
import 'package:wan_android/features/cart/data/cart_storage.dart';
import 'package:wan_android/features/cart/domain/cart_item.dart';
import 'package:wan_android/features/cart/presentation/providers/cart_providers.dart';
import 'package:wan_android/features/favorites/data/favorites_dependencies.dart';
import 'package:wan_android/features/favorites/data/favorites_storage.dart';
import 'package:wan_android/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:wan_android/features/orders/data/orders_dependencies.dart';
import 'package:wan_android/features/orders/data/orders_storage.dart';
import 'package:wan_android/features/orders/domain/order.dart';
import 'package:wan_android/features/orders/presentation/providers/orders_providers.dart';
import 'package:wan_android/features/products/domain/product.dart';

const product = Product(
  id: 1,
  title: '商品',
  description: '',
  category: 'test',
  price: 10,
  discountPercentage: 0,
  rating: 4,
  stock: 10,
  thumbnail: '',
  images: [],
  tags: null,
);
const address = ShippingAddress(
  name: '张三',
  phone: '13800138000',
  detail: '测试地址',
);
const item = CartItem(
  productId: 1,
  title: '商品',
  thumbnail: '',
  unitPrice: 10,
  quantity: 1,
);

class ControlledCartStorage extends CartStorage {
  final started = Completer<void>();
  Completer<void>? gate;
  bool fail = false;
  List<CartItem> persisted = [];
  @override
  Future<List<CartItem>> load() async => persisted;
  @override
  Future<void> save(List<CartItem> items) async {
    if (!started.isCompleted) started.complete();
    await gate?.future;
    if (fail) throw StateError('写入失败');
    persisted = List.of(items);
  }
}

class MemoryFavoritesStorage extends FavoritesStorage {
  bool fail = false;
  List<Product> persisted = [];
  @override
  Future<List<Product>> load() async => persisted;
  @override
  Future<void> save(List<Product> products) async {
    await Future<void>.delayed(Duration.zero);
    if (fail) throw StateError("收藏保存失败");
    persisted = List.of(products);
  }
}

class MemoryOrdersStorage extends OrdersStorage {
  bool fail = false;
  List<Order> persisted = [];
  @override
  Future<List<Order>> load() async => persisted;
  @override
  Future<void> save(List<Order> orders) async {
    if (fail) throw StateError("订单保存失败");
    persisted = List.of(orders);
  }
}

class DelayedCartStorage extends ControlledCartStorage {
  final initialRead = Completer<List<CartItem>>();
  @override
  Future<List<CartItem>> load() => initialRead.future;
}

void main() {
  test('购物车保存完成前保持原状态', () async {
    final storage = ControlledCartStorage()..gate = Completer<void>();
    final container = ProviderContainer(
      overrides: [cartStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    await container.read(cartProvider.future);
    final operation = container.read(cartProvider.notifier).addProduct(product);
    await storage.started.future;
    final beforeSave = container.read(cartProvider).requireValue;
    storage.gate!.complete();
    await operation;
    expect(beforeSave, isEmpty);
    expect(container.read(cartProvider).requireValue.single.quantity, 1);
  });
  test('购物车保存失败保留原值，失败后仍可再次操作', () async {
    final storage = ControlledCartStorage()..fail = true;
    final container = ProviderContainer(
      overrides: [cartStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    await container.read(cartProvider.future);
    final notifier = container.read(cartProvider.notifier);
    await expectLater(notifier.addProduct(product), throwsStateError);
    expect(container.read(cartProvider).requireValue, isEmpty);
    storage.fail = false;
    await notifier.addProduct(product);
    expect(storage.persisted.single.quantity, 1);
  });
  test('同时加购不会丢失数量', () async {
    final storage = ControlledCartStorage();
    final container = ProviderContainer(
      overrides: [cartStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(cartProvider.notifier);
    await Future.wait([
      notifier.addProduct(product),
      notifier.addProduct(product),
    ]);
    expect(container.read(cartProvider).requireValue.single.quantity, 2);
    expect(storage.persisted.single.quantity, 2);
  });
  test('同时切换收藏两次恢复未收藏', () async {
    final storage = MemoryFavoritesStorage();
    final container = ProviderContainer(
      overrides: [favoritesStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(favoritesProvider.notifier);
    await Future.wait([notifier.toggle(product), notifier.toggle(product)]);
    expect(container.read(favoritesProvider).requireValue, isEmpty);
    expect(storage.persisted, isEmpty);
  });
  test('同时创建两个订单均保留', () async {
    final storage = MemoryOrdersStorage();
    final container = ProviderContainer(
      overrides: [ordersStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(ordersProvider.notifier);
    await Future.wait([
      notifier.placeOrder(cartItems: [item], address: address),
      notifier.placeOrder(cartItems: [item], address: address),
    ]);
    expect(container.read(ordersProvider).requireValue, hasLength(2));
    expect(storage.persisted, hasLength(2));
  });
  test('订单冻结提交时的列表，调用方随后修改不影响订单', () async {
    final storage = MemoryOrdersStorage();
    final container = ProviderContainer(
      overrides: [ordersStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final items = [item];
    final operation = container
        .read(ordersProvider.notifier)
        .placeOrder(cartItems: items, address: address);
    items.clear();
    final order = await operation;
    expect(order.items.single.productId, 1);
  });
  test('清空也等待初始读盘完成，不被旧值覆盖', () async {
    final storage = DelayedCartStorage();
    final container = ProviderContainer(
      overrides: [cartStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final operation = container.read(cartProvider.notifier).clear();
    storage.initialRead.complete([item]);
    await operation;
    expect(container.read(cartProvider).requireValue, isEmpty);
    expect(storage.persisted, isEmpty);
  });
  test('收藏写入失败不发布状态，重试仍然可用', () async {
    final storage = MemoryFavoritesStorage()..fail = true;
    final container = ProviderContainer(
      overrides: [favoritesStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(favoritesProvider.notifier);
    await expectLater(notifier.toggle(product), throwsStateError);
    expect(container.read(favoritesProvider).requireValue, isEmpty);
    storage.fail = false;
    await notifier.toggle(product);
    expect(storage.persisted.single.id, product.id);
  });
  test('订单写入失败不发布状态，重试仍然可用', () async {
    final storage = MemoryOrdersStorage()..fail = true;
    final container = ProviderContainer(
      overrides: [ordersStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(ordersProvider.notifier);
    await expectLater(
      notifier.placeOrder(cartItems: [item], address: address),
      throwsStateError,
    );
    expect(container.read(ordersProvider).requireValue, isEmpty);
    storage.fail = false;
    await notifier.placeOrder(cartItems: [item], address: address);
    expect(storage.persisted, hasLength(1));
  });
}
