import 'cart_item.dart';

/// 一次结算的选择快照。累计新增数量只在当前会话使用，不改变持久化 JSON。
/// 记录选择时的计数，扣量时才可以区分旧购买数量与等待期间新增的数量。
class CartSnapshot {
  CartSnapshot({
    required List<CartItem> items,
    required Map<int, int> additions,
  }) : items = List.unmodifiable(items),
       additions = Map.unmodifiable(additions);
  final List<CartItem> items;
  final Map<int, int> additions;
}
