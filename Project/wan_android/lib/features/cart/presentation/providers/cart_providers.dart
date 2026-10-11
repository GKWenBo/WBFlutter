import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/async/serial_task_queue.dart';
import '../../../products/models.dart';
import '../../data/cart_dependencies.dart';
import '../../domain/cart_item.dart';
import '../../domain/cart_snapshot.dart';

part 'cart_providers.g.dart';

/// 购物车状态 ≈ 你 iOS 里的 CartViewModel（单例、跨页共享）。
///
/// 用 AsyncNotifier（而不是同步 Notifier）：初始值要从磁盘异步读取，
/// 这和 M4 的 ProductList 是同一种模式——只是这里的"异步数据源"是本地存储而不是网络。
///
/// 关键教训 1（真实踩过的坑）：如果初始读盘和"加购"各自独立地异步跑，
/// 迟到的读盘结果可能用"读盘那一刻的旧数据"覆盖掉刚加购的新数据（竞态条件）。
/// M7 维护演进：`await future` 等待初始化，串行队列才保证多个修改互斥。
/// 保存成功后发布状态，调用方能可靠判断操作是否完成。
///
/// 关键教训 2：代码生成的 provider 默认是 autoDispose——没人 watch 时会被回收。
/// 购物车这种"全局唯一、该活满整个 App 生命周期"的状态不能靠"正好有人在 watch"这种偶然性
/// 兜底（万一某个异步方法还没跑完、最后一个监听者恰好被移除，state= 会因 provider 已销毁而报错）。
/// 所以显式标 keepAlive: true，常驻不回收（呼应 M6 的 categoriesProvider）。
@Riverpod(keepAlive: true)
class Cart extends _$Cart {
  final _queue = SerialTaskQueue();
  final _additions = <int, int>{};
  @override
  Future<List<CartItem>> build() {
    return ref
        .read(cartStorageProvider)
        .load()
        .then(List<CartItem>.unmodifiable);
  }

  Future<void> _commit(List<CartItem> items) async {
    final previous = {
      for (final item in state.requireValue) item.productId: item.quantity,
    };
    await ref.read(cartStorageProvider).save(items);
    if (!ref.mounted) return;
    for (final item in items) {
      final increase = item.quantity - (previous[item.productId] ?? 0);
      if (increase > 0) {
        _additions.update(
          item.productId,
          (count) => count + increase,
          ifAbsent: () => increase,
        );
      }
    }
    state = AsyncData(List.unmodifiable(items));
  }

  /// 在同一队列中捕获状态与新增计数，避免二者来自不同修改时刻。
  Future<CartSnapshot> capture() => _queue.run(() async {
    final items = await future;
    return CartSnapshot(items: items, additions: _additions);
  });

  /// 加入购物车：已存在同款商品就叠加数量，否则新增一行。
  Future<void> addProduct(Product product, {int quantity = 1}) =>
      _queue.run(() async {
        if (quantity <= 0) {
          throw ArgumentError.value(quantity, "quantity", "必须大于 0");
        }
        final current = await future; // 拿到当前已确定的最新列表，避免竞态覆盖
        final index = current.indexWhere((e) => e.productId == product.id);
        final List<CartItem> updated;
        if (index >= 0) {
          final merged = current[index].copyWith(
            quantity: current[index].quantity + quantity,
          );
          updated = [
            for (final item in current)
              if (item.productId == product.id) merged else item,
          ];
        } else {
          updated = [
            ...current,
            CartItem(
              productId: product.id,
              title: product.title,
              thumbnail: product.thumbnail,
              unitPrice: product.discountedPrice,
              quantity: quantity,
            ),
          ];
        }
        await _commit(updated);
      });

  /// 改数量；降到 0 或以下直接移除这一行。
  Future<void> updateQuantity(int productId, int quantity) {
    if (quantity <= 0) {
      return removeItem(productId);
    }
    return _queue.run(() async {
      final current = await future;
      final updated = [
        for (final item in current)
          if (item.productId == productId)
            item.copyWith(quantity: quantity)
          else
            item,
      ];
      await _commit(updated);
    });
  }

  Future<void> removeItem(int productId) => _queue.run(() async {
    final current = await future;
    final updated = current.where((e) => e.productId != productId).toList();
    await _commit(updated);
  });

  Future<void> clear() => _queue.run(() async {
    await future;
    await _commit(const []);
  });

  /// 结算仅消费快照数量，不清空请求期间新加的商品（M10 维护演进）。
  Future<void> consume(CartSnapshot snapshot) => _queue.run(() async {
    final current = await future;
    final purchased = <int, int>{};
    for (final item in snapshot.items) {
      purchased.update(
        item.productId,
        (n) => n + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }
    final updated = <CartItem>[];
    for (final item in current) {
      final addedSinceSelection =
          (_additions[item.productId] ?? 0) -
          (snapshot.additions[item.productId] ?? 0);
      final originalRemaining = (item.quantity - addedSinceSelection).clamp(
        0,
        item.quantity,
      );
      final toConsume = (purchased[item.productId] ?? 0).clamp(
        0,
        originalRemaining,
      );
      final remaining = item.quantity - toConsume;
      if (remaining > 0) updated.add(item.copyWith(quantity: remaining));
    }
    await _commit(updated);
  });
}

/// 派生 provider：购物车总件数（用于 Tab 角标）。
/// 用 .asData?.value（Riverpod 3.x 用法，呼应 M4）：还在 loading/error 时先当空列表算，
/// 磁盘读取通常一瞬间完成，用户几乎不会看到角标"闪一下 0"。
@riverpod
int cartTotalCount(Ref ref) {
  final items = ref.watch(cartProvider).asData?.value ?? const [];
  return items.fold(0, (sum, item) => sum + item.quantity);
}

/// 派生 provider：购物车总金额。
@riverpod
double cartTotalPrice(Ref ref) {
  final items = ref.watch(cartProvider).asData?.value ?? const [];
  return items.fold(0.0, (sum, item) => sum + item.subtotal);
}
