// 测试 Orders notifier + 持久化：重点验证"冻结"语义（快照映射、金额计算）
// 和嵌套对象/枚举/DateTime 的序列化往返（explicitToJson 是否真的生效）。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wan_android/features/cart/domain/cart_item.dart';
import 'package:wan_android/features/orders/data/orders_storage.dart';
import 'package:wan_android/features/orders/domain/order.dart';
import 'package:wan_android/features/orders/presentation/providers/orders_providers.dart';

CartItem _makeCartItem(int id, {double price = 100, int quantity = 1}) =>
    CartItem(
      productId: id,
      title: 'product-$id',
      thumbnail: 'http://x/$id.png',
      unitPrice: price,
      quantity: quantity,
    );

const _address = ShippingAddress(
  name: '张三',
  phone: '13800138000',
  detail: '北京市海淀区中关村大街 1 号',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('placeOrder：购物车行被冻结成订单行，金额/件数/状态正确，新单排最前', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(ordersProvider.notifier);
    final first = await notifier.placeOrder(
      cartItems: [
        _makeCartItem(1, price: 100, quantity: 2), // 小计 200
        _makeCartItem(2, price: 50), // 小计 50
      ],
      address: _address,
    );

    expect(first.items, hasLength(2));
    expect(first.items.first.productId, 1);
    expect(first.totalPrice, closeTo(250, 0.001));
    expect(first.totalCount, 3);
    expect(first.status, OrderStatus.submitted);

    // 再下一单，验证新单插在最前（列表按时间倒序）。
    final second = await notifier.placeOrder(
      cartItems: [_makeCartItem(3)],
      address: _address,
    );
    final orders = await container.read(ordersProvider.future);
    expect(orders, hasLength(2));
    expect(orders.first.id, second.id);
  });

  test('持久化往返：嵌套对象/枚举/DateTime 都能序列化回来（explicitToJson 生效）', () async {
    final container1 = ProviderContainer();
    await container1.read(ordersProvider.notifier).placeOrder(
      cartItems: [_makeCartItem(7, price: 33.5, quantity: 2)],
      address: _address,
    );
    container1.dispose();

    // 新 container 重新从磁盘读，等于"杀掉 App 再打开"。
    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    final orders = await container2.read(ordersProvider.future);

    expect(orders, hasLength(1));
    final order = orders.first;
    expect(order.items.single.title, 'product-7'); // 嵌套 List<OrderItem>
    expect(order.items.single.subtotal, closeTo(67, 0.001));
    expect(order.address.name, '张三'); // 嵌套单对象
    expect(order.status, OrderStatus.submitted); // 枚举（存的是 'submitted' 字符串）
    expect(order.createdAt.year, DateTime.now().year); // DateTime ISO8601 往返
  });

  test('AddressStorage 往返 + savedAddress provider 读到保存的地址', () async {
    await AddressStorage().save(_address);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final loaded = await container.read(savedAddressProvider.future);

    expect(loaded, isNotNull);
    expect(loaded!.phone, '13800138000');
    expect(loaded.detail, contains('中关村'));
  });

  test('没存过地址时 savedAddress 返回 null（结算页表单保持空白）', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(savedAddressProvider.future), isNull);
  });
}
