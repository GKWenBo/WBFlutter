import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/order.dart';

/// 订单的本地持久化。和 Cart/Favorites 一样，本地这份就是"数据真身"
/// （mock 阶段没有服务器，丢了就真丢了）——所以读的时候**不**像 ProductsCache
/// 那样宽容地吞解析错误：订单数据坏了是要暴露出来的问题，不是"当没有"就完事。
class OrdersStorage {
  static const _key = 'orders';

  Future<List<Order>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> save(List<Order> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(orders.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }
}

/// 默认收货地址的持久化（最近一次下单填的地址，下次结算自动带出）。
/// 单个对象而不是列表，所以没有"多地址管理"——真实项目的地址簿留作练习方向。
class AddressStorage {
  static const _key = 'default_address';

  Future<ShippingAddress?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return ShippingAddress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(ShippingAddress address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(address.toJson()));
  }
}
