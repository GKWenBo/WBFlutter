import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'orders_storage.dart';

/// 数据层装配入口；测试在这里替换依赖，页面状态只消费依赖。
final ordersStorageProvider = Provider<OrdersStorage>((ref) => OrdersStorage());
final addressStorageProvider = Provider<AddressStorage>(
  (ref) => AddressStorage(),
);
