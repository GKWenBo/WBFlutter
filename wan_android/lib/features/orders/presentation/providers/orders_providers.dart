import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../cart/domain/cart_item.dart';
import '../../data/orders_storage.dart';
import '../../domain/order.dart';

part 'orders_providers.g.dart';

@riverpod
OrdersStorage ordersStorage(Ref ref) => OrdersStorage();

@riverpod
AddressStorage addressStorage(Ref ref) => AddressStorage();

/// 上次保存的默认地址（结算页用来预填表单）。
/// 一次性异步读取，没有"修改后要通知谁"的需求，所以一个函数 provider 就够，
/// 不用 Notifier——下单成功后 invalidate 一下让它下次重读即可。
@riverpod
Future<ShippingAddress?> savedAddress(Ref ref) {
  return ref.watch(addressStorageProvider).load();
}

/// 订单列表：第三个 AsyncNotifier + keepAlive（Cart/Favorites/Orders 同一模式，
/// 到这里你应该已经能把这套"异步初始化的全局状态"当模板默写了）。
@Riverpod(keepAlive: true)
class Orders extends _$Orders {
  @override
  Future<List<Order>> build() {
    return ref.read(ordersStorageProvider).load();
  }

  /// 提交订单（mock）：把购物车行冻结成订单、本地生成单号、模拟一段网络耗时。
  ///
  /// 注意这个方法**只管订单自己的事**，不去清空购物车——
  /// "下单成功后清空购物车 + 存默认地址 + 跳转"是结算页面的**流程编排**，
  /// 放在 UI 层的提交回调里（≈ 你 iOS 里 Coordinator/调用方串联多个 service，
  /// 而不是让 OrderService 反手去改 CartService 的状态）。
  /// 这样 orders 对 cart 只依赖它的**模型**（CartItem 入参），不依赖它的状态管理。
  Future<Order> placeOrder({
    required List<CartItem> cartItems,
    required ShippingAddress address,
  }) async {
    final current = await future; // 老规矩：先拿最新值（M7 教训 1）

    // 模拟网络往返（真实项目这里是 POST /orders）。
    // 放在 await future 之后：让"请求期间又有别的状态变化"的窗口尽量小。
    await Future<void>.delayed(const Duration(milliseconds: 800));

    final order = Order(
      // 单号用时间戳凑合（mock 够用且天然唯一）；真后端会返回正经单号。
      id: 'WS${DateTime.now().millisecondsSinceEpoch}',
      items: cartItems.map(OrderItem.fromCartItem).toList(),
      address: address,
      totalPrice: cartItems.fold(0.0, (sum, e) => sum + e.subtotal),
      createdAt: DateTime.now(),
      status: OrderStatus.submitted,
    );

    final updated = [order, ...current]; // 新订单排最前（列表按时间倒序）
    state = AsyncData(updated);
    ref.read(ordersStorageProvider).save(updated); // 落盘不 await，同前
    return order;
  }
}

/// 派生：订单数（"我的"页菜单行显示），写法同 favoritesCount。
@riverpod
int ordersCount(Ref ref) {
  return ref.watch(ordersProvider).asData?.value.length ?? 0;
}
