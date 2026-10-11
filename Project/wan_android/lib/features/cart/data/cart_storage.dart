import '../../../core/storage/json_preferences_store.dart';
import '../domain/cart_item.dart';

/// 购物车的本地持久化 ≈ 你封装的 UserDefaults 读写器。
///
/// shared_preferences 只能存基础类型（String/int/bool/...），
/// 存"一组对象"要先把 `List<CartItem>` 编码成 JSON 字符串再存，取出来再解码——
/// 这就是为什么 CartItem 也要有 @JsonSerializable()。
class CartStorage {
  static const _key = 'cart_items';
  final JsonPreferencesStore _store;
  CartStorage({JsonPreferencesStore? store})
    : _store = store ?? JsonPreferencesStore();

  Future<List<CartItem>> load() async {
    final data = await _store.read(_key);
    if (data == null) return const [];
    return (data as List<dynamic>)
        .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> save(List<CartItem> items) async {
    await _store.write(_key, items.map((item) => item.toJson()).toList());
  }
}
