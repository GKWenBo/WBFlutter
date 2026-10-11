import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cart_storage.dart';

/// 数据层装配入口；测试在这里替换依赖，页面状态只消费依赖。
final cartStorageProvider = Provider<CartStorage>((ref) => CartStorage());
