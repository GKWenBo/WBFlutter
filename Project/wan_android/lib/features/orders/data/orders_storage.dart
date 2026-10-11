import '../../../core/storage/json_preferences_store.dart';
import '../domain/order.dart';

/// 订单的本地持久化。和 Cart/Favorites 一样，本地这份就是"数据真身"
/// （mock 阶段没有服务器，丢了就真丢了）——所以读的时候**不**像 ProductsCache
/// 那样宽容地吞解析错误：订单数据坏了是要暴露出来的问题，不是"当没有"就完事。
class OrdersStorage {
  static const _key = 'orders';
  final JsonPreferencesStore _store;
  OrdersStorage({JsonPreferencesStore? store})
    : _store = store ?? JsonPreferencesStore();

  Future<List<Order>> load() async {
    final data = await _store.read(_key);
    if (data == null) return const [];
    return (data as List<dynamic>)
        .map((item) => Order.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> save(List<Order> items) async {
    await _store.write(_key, items.map((item) => item.toJson()).toList());
  }
}

/// M10：最近使用的收货地址，仍沿用旧键名和 JSON 格式。
class AddressStorage {
  static const _key = 'default_address';
  final JsonPreferencesStore _store;
  AddressStorage({JsonPreferencesStore? store})
    : _store = store ?? JsonPreferencesStore();
  Future<ShippingAddress?> load() async {
    final data = await _store.read(_key);
    return data == null
        ? null
        : ShippingAddress.fromJson(data as Map<String, dynamic>);
  }

  Future<void> save(ShippingAddress address) =>
      _store.write(_key, address.toJson());
}
