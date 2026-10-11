import '../../../core/storage/json_preferences_store.dart';
import '../../products/models.dart';

/// 收藏的本地持久化，写法与 CartStorage 完全同构（≈ 又一个 UserDefaults 读写器）。
///
/// 设计决策：存的是**完整 Product 快照**，而不是只存一串商品 id。
/// - 只存 id 的话，打开收藏页要拿着 id 逐个去请求接口，断网时收藏页直接废掉；
/// - 存快照则收藏页天然离线可用（这正是 M9 的主题之一），代价是数据可能过时
///   （价格变了收藏里还是旧价）——电商 App 通常接受这种取舍，进详情页时自然会刷新。
/// 这和 M7 CartItem 的"快照式购物车"是同一个思路，只是这里直接复用 Product 模型，
/// 不必再造一个裁剪过的 FavoriteItem。
class FavoritesStorage {
  static const _key = 'favorite_products';
  final JsonPreferencesStore _store;
  FavoritesStorage({JsonPreferencesStore? store})
    : _store = store ?? JsonPreferencesStore();

  Future<List<Product>> load() async {
    final data = await _store.read(_key);
    if (data == null) return const [];
    return (data as List<dynamic>)
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> save(List<Product> items) async {
    await _store.write(_key, items.map((item) => item.toJson()).toList());
  }
}
