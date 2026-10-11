import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/async/serial_task_queue.dart';
import '../../../products/models.dart';
import '../../data/favorites_dependencies.dart';

part 'favorites_providers.g.dart';

/// 收藏列表的全局状态，与 Cart 同一套模式：
/// AsyncNotifier（初始值要异步读盘）+ keepAlive: true（跨页共享、活满 App 生命周期）。
/// M7 维护演进：等待初始化 + 串行修改 + 保存成功才发布状态；keepAlive 保证跨页存活。
@Riverpod(keepAlive: true)
class Favorites extends _$Favorites {
  final _queue = SerialTaskQueue();
  @override
  Future<List<Product>> build() {
    return ref
        .read(favoritesStorageProvider)
        .load()
        .then(List<Product>.unmodifiable);
  }

  /// 收藏/取消收藏用同一个入口：已收藏就移除，没收藏就追加。
  /// UI 侧只需要一个♥按钮来回点，不用分两个方法（≈ 你 iOS 里的 toggleFavorite(_:)）。
  Future<void> toggle(Product product) => _queue.run(() async {
    final current = await future; // 先拿当前最新值再改（M7 教训 1：防竞态覆盖）
    final exists = current.any((e) => e.id == product.id);
    final updated = exists
        ? current.where((e) => e.id != product.id).toList()
        : [...current, product];
    await ref.read(favoritesStorageProvider).save(updated);
    if (ref.mounted) state = AsyncData(List.unmodifiable(updated));
  });
}

/// 派生 + family 的组合："某个商品是否已收藏"。
///
/// 详情页的♥按钮 watch 它：isFavoriteProvider(product.id)。
/// 它 watch 整个收藏列表，列表一变，**只有关心这个 id 的那个实例**会重新计算并通知
/// 自己的订阅者——比让详情页直接 watch 整个 favoritesProvider 再自己 contains 更精准，
/// 也把"怎么判断已收藏"这条逻辑收拢到一处（UI 里不散落 contains 判断）。
@riverpod
bool isFavorite(Ref ref, int productId) {
  final items = ref.watch(favoritesProvider).asData?.value ?? const [];
  return items.any((e) => e.id == productId);
}

/// 派生：收藏总数（"我的"页菜单行上显示）。写法呼应 cartTotalCount。
@riverpod
int favoritesCount(Ref ref) {
  return ref.watch(favoritesProvider).asData?.value.length ?? 0;
}
