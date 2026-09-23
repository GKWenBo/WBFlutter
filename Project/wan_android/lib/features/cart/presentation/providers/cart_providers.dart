import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../products/domain/product.dart';
import '../../data/cart_storage.dart';
import '../../domain/cart_item.dart';

part 'cart_providers.g.dart';

@riverpod
CartStorage cartStorage(Ref ref) => CartStorage();

/// 购物车状态 ≈ 你 iOS 里的 CartViewModel（单例、跨页共享）。
///
/// 用 AsyncNotifier（而不是同步 Notifier）：初始值要从磁盘异步读取，
/// 这和 M4 的 ProductList 是同一种模式——只是这里的"异步数据源"是本地存储而不是网络。
///
/// 关键教训 1（真实踩过的坑）：如果初始读盘和"加购"各自独立地异步跑，
/// 迟到的读盘结果可能用"读盘那一刻的旧数据"覆盖掉刚加购的新数据（竞态条件）。
/// 解法：每次修改前用 `await future` 拿到"当前已确定的最新值"再改，
/// future 会等待 build() 完成、且之后始终反映最新 state，不会用旧值覆盖新值。
///
/// 关键教训 2：代码生成的 provider 默认是 autoDispose——没人 watch 时会被回收。
/// 购物车这种"全局唯一、该活满整个 App 生命周期"的状态不能靠"正好有人在 watch"这种偶然性
/// 兜底（万一某个异步方法还没跑完、最后一个监听者恰好被移除，state= 会因 provider 已销毁而报错）。
/// 所以显式标 keepAlive: true，常驻不回收（呼应 M6 的 categoriesProvider）。
@Riverpod(keepAlive: true)
class Cart extends _$Cart {
  @override
  Future<List<CartItem>> build() {
    return ref.read(cartStorageProvider).load();
  }

  void _persist(List<CartItem> items) {
    // 落盘是"背后悄悄做的副作用"，不 await，不阻塞 UI。
    ref.read(cartStorageProvider).save(items);
  }

  /// 加入购物车：已存在同款商品就叠加数量，否则新增一行。
  Future<void> addProduct(Product product, {int quantity = 1}) async {
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
    state = AsyncData(updated);
    _persist(updated);
  }

  /// 改数量；降到 0 或以下直接移除这一行。
  Future<void> updateQuantity(int productId, int quantity) async {
    if (quantity <= 0) {
      await removeItem(productId);
      return;
    }
    final current = await future;
    final updated = [
      for (final item in current)
        if (item.productId == productId)
          item.copyWith(quantity: quantity)
        else
          item,
    ];
    state = AsyncData(updated);
    _persist(updated);
  }

  Future<void> removeItem(int productId) async {
    final current = await future;
    final updated = current.where((e) => e.productId != productId).toList();
    state = AsyncData(updated);
    _persist(updated);
  }

  Future<void> clear() async {
    state = const AsyncData([]);
    _persist(const []);
  }
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
