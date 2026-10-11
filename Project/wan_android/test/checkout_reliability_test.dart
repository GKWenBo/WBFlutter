import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wan_android/app/checkout/checkout_controller.dart';
import 'package:wan_android/features/cart/api.dart';
import 'package:wan_android/features/cart/data/cart_dependencies.dart';
import 'package:wan_android/features/cart/data/cart_storage.dart';
import 'package:wan_android/features/cart/models.dart';
import 'package:wan_android/features/orders/api.dart';
import 'package:wan_android/features/orders/data/orders_dependencies.dart';
import 'package:wan_android/features/orders/data/orders_storage.dart';
import 'package:wan_android/features/orders/models.dart';
import 'package:wan_android/features/products/models.dart';

const address = ShippingAddress(name: '张三', phone: '13800138000', detail: '地址');
const item = CartItem(
  productId: 1,
  title: '商品',
  thumbnail: '',
  unitPrice: 10,
  quantity: 1,
);
Product product(int id) => Product(
  id: id,
  title: '商品$id',
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

class CartMemory extends CartStorage {
  bool fail = false;
  List<CartItem> items = [item];
  @override
  Future<List<CartItem>> load() async => items;
  @override
  Future<void> save(List<CartItem> value) async {
    if (fail) throw StateError('购物车保存失败');
    items = List.of(value);
  }
}

class OrderMemory extends OrdersStorage {
  int saves = 0;
  bool fail = false;
  final started = Completer<void>();
  Completer<void>? gate;
  List<Order> orders = [];
  @override
  Future<List<Order>> load() async => orders;
  @override
  Future<void> save(List<Order> value) async {
    if (!started.isCompleted) started.complete();
    await gate?.future;
    if (fail) throw StateError("订单保存失败");
    saves++;
    orders = List.of(value);
  }
}

class AddressMemory extends AddressStorage {
  bool fail = false;
  ShippingAddress? address;
  @override
  Future<ShippingAddress?> load() async => address;
  @override
  Future<void> save(ShippingAddress value) async {
    if (fail) throw StateError('地址保存失败');
    address = value;
  }
}

void main() {
  ProviderContainer containerFor(
    CartMemory cart,
    OrderMemory orders,
    AddressMemory addresses,
  ) {
    final container = ProviderContainer(
      overrides: [
        cartStorageProvider.overrideWithValue(cart),
        ordersStorageProvider.overrideWithValue(orders),
        addressStorageProvider.overrideWithValue(addresses),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('重复提交复用任务，期间新增商品与数量保留', () async {
    final cart = CartMemory();
    final orders = OrderMemory()..gate = Completer<void>();
    final container = containerFor(cart, orders, AddressMemory());
    final checkout = container.read(checkoutControllerProvider.notifier);
    final first = checkout.submit(address);
    final second = checkout.submit(address);
    await orders.started.future;
    await container.read(cartProvider.notifier).addProduct(product(1));
    await container.read(cartProvider.notifier).addProduct(product(2));
    orders.gate!.complete();
    final results = await Future.wait([first, second]);
    expect(results.first.order.id, results.last.order.id);
    expect(orders.orders, hasLength(1));
    expect(cart.items.map((e) => e.productId), [1, 2]);
    expect(cart.items.first.quantity, 1);
  });
  test('订单成功但购物车保存失败，重试不重复建单或扣量', () async {
    final cart = CartMemory()..fail = true;
    final orders = OrderMemory();
    final container = containerFor(cart, orders, AddressMemory());
    final checkout = container.read(checkoutControllerProvider.notifier);
    final result = await checkout.submit(address);
    expect(result.needsCartRetry, isTrue);
    expect(cart.items, hasLength(1));
    cart.fail = false;
    final retry = await checkout.retryPending();
    expect(retry.order.id, result.order.id);
    expect(retry.needsCartRetry, isFalse);
    await checkout.retryPending();
    expect(orders.saves, 1);
    expect(cart.items, isEmpty);
  });
  test('地址失败只产生附属警告，重试仅保存地址', () async {
    final cart = CartMemory();
    final orders = OrderMemory();
    final addresses = AddressMemory()..fail = true;
    final container = containerFor(cart, orders, addresses);
    final checkout = container.read(checkoutControllerProvider.notifier);
    final result = await checkout.submit(address);
    expect(result.needsAddressRetry, isTrue);
    expect(result.needsCartRetry, isFalse);
    expect(container.read(ordersProvider).requireValue, hasLength(1));
    addresses.fail = false;
    final retry = await checkout.retryPending();
    expect(retry.needsAddressRetry, isFalse);
    expect(orders.saves, 1);
    expect(addresses.address?.name, '张三');
  });
  test('新订单失败后，上一单的地址检查点仍能恢复', () async {
    final cart = CartMemory();
    final orders = OrderMemory();
    final addresses = AddressMemory()..fail = true;
    final container = containerFor(cart, orders, addresses);
    final checkout = container.read(checkoutControllerProvider.notifier);
    final previous = await checkout.submit(address);
    await container.read(cartProvider.notifier).addProduct(product(2));
    orders.fail = true;
    await expectLater(checkout.submit(address), throwsStateError);
    addresses.fail = false;
    final restored = await checkout.retryPending();
    expect(restored.order.id, previous.order.id);
    expect(restored.needsAddressRetry, isFalse);
    expect(orders.saves, 1);
    expect(cart.items.single.productId, 2);
  });

  test('提交期间删除再加入同款商品，不扣除新加入的数量', () async {
    final cart = CartMemory();
    final orders = OrderMemory()..gate = Completer<void>();
    final container = containerFor(cart, orders, AddressMemory());
    final operation = container
        .read(checkoutControllerProvider.notifier)
        .submit(address);
    await orders.started.future;
    final notifier = container.read(cartProvider.notifier);
    await notifier.removeItem(1);
    await notifier.addProduct(product(1));
    orders.gate!.complete();
    await operation;
    expect(cart.items.single.quantity, 1);
    expect(orders.orders.single.items.single.quantity, 1);
  });
}
