import '../../../core/storage/json_preferences_store.dart';
import '../domain/product.dart';

/// 首页第一页商品的本地缓存——给"断网打开 App 也能看到东西"兜底用。
///
/// 和 FavoritesStorage/CartStorage 是同一套 JSON⇆shared_preferences 手法，
/// 但**语义完全不同**，值得分清楚：
/// - Cart/Favorites 是**数据的唯一真身**（source of truth 在本地，丢了就真丢了）；
/// - 这里只是**网络数据的副本**（source of truth 在服务器，本地这份随时可以扔）。
/// 所以它的读写都"宽容"：缓存坏了就当没有（返回 null），绝不能让一份可有可无的
/// 副本把首页搞崩。≈ 你 iOS 里 NSCache/磁盘缓存的定位，而不是 Core Data 主存储。
///
/// 简化说明：这里没做过期时间（TTL）。对"兜底展示"场景，旧数据也比白屏强；
/// 真要做 TTL（比如超过 24h 不用），需要明确缓存过期策略时，可额外保存时间戳；当前仍未实现 TTL。
class ProductsCache {
  static const _key = 'home_products_cache';
  final JsonPreferencesStore _store;
  ProductsCache({JsonPreferencesStore? store})
    : _store = store ?? JsonPreferencesStore();

  Future<List<Product>?> load() async {
    try {
      final data = await _store.read(_key);
      if (data == null) return null;
      return (data as List<dynamic>)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(List<Product> items) async {
    try {
      await _store.write(_key, items.map((item) => item.toJson()).toList());
    } catch (_) {
      /* M9：缓存副本写入失败不影响网络结果。 */
    }
  }
}
