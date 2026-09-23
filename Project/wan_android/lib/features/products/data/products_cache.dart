import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
/// 真要做 TTL（比如超过 24h 不用），存的时候带上时间戳即可——留到 M13 性能收尾再谈。
class ProductsCache {
  static const _key = 'home_products_cache';

  /// 读缓存。没有缓存、或缓存解析失败，都返回 null（调用方自己决定怎么办）。
  Future<List<Product>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // 缓存损坏（App 升级后字段变了之类）→ 当作没有缓存，而不是抛错。
      return null;
    }
  }

  Future<void> save(List<Product> products) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(products.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }
}
