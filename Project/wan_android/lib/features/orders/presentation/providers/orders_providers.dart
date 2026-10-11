import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/async/serial_task_queue.dart';
import '../../../cart/models.dart';
import '../../data/orders_dependencies.dart';
import '../../domain/order.dart';

part 'orders_providers.g.dart';

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
  final _queue = SerialTaskQueue();
  int _sequence = 0;
  @override
  Future<List<Order>> build() {
    return ref
        .read(ordersStorageProvider)
        .load()
        .then(List<Order>.unmodifiable);
  }

  /// 提交订单（mock）：把购物车行冻结成订单、本地生成单号、模拟一段网络耗时。
  ///
  /// M10 维护演进：订单只保存自己；跨模块结算流程交给应用层 CheckoutController。
  Future<Order> placeOrder({
    required List<CartItem> cartItems,
    required ShippingAddress address,
  }) {
    final snapshot = List<CartItem>.unmodifiable(cartItems);
    return _queue.run(() async {
      if (snapshot.isEmpty) throw ArgumentError("不能提交空订单");
      final current = await future; // 老规矩：先拿最新值（M7 教训 1）

      // 模拟网络往返（真实项目这里是 POST /orders）。
      // 整项任务留在串行队列中，请求期间下一项订单修改仍需等待。
      await Future<void>.delayed(const Duration(milliseconds: 800));

      final order = Order(
        // Mock 单号：微秒时间 + 容器内序号；真实项目由后端分配。
        id: 'WS${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
        items: snapshot.map(OrderItem.fromCartItem).toList(),
        address: address,
        totalPrice: snapshot.fold(0.0, (sum, e) => sum + e.subtotal),
        createdAt: DateTime.now(),
        status: OrderStatus.submitted,
      );

      final updated = [order, ...current]; // 新订单排最前（列表按时间倒序）
      await ref.read(ordersStorageProvider).save(updated);
      if (ref.mounted) state = AsyncData(List.unmodifiable(updated));
      return order;
    });
  }
}

/// 派生：订单数（"我的"页菜单行显示），写法同 favoritesCount。
@riverpod
int ordersCount(Ref ref) {
  return ref.watch(ordersProvider).asData?.value.length ?? 0;
}
