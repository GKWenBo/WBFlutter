import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/cart_item.dart';

/// 购物车的本地持久化 ≈ 你封装的 UserDefaults 读写器。
///
/// shared_preferences 只能存基础类型（String/int/bool/...），
/// 存"一组对象"要先把 `List<CartItem>` 编码成 JSON 字符串再存，取出来再解码——
/// 这就是为什么 CartItem 也要有 @JsonSerializable()。
class CartStorage {
  static const _key = 'cart_items';

  Future<List<CartItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<CartItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }
}
