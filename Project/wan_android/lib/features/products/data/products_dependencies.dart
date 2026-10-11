import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'products_cache.dart';
import 'products_repository.dart';

/// 数据层装配入口；测试在这里替换依赖，页面状态只消费依赖。
final productsRepositoryProvider = Provider<ProductsRepository>(
  (ref) => ProductsRepository(dio: ref.watch(dioProvider)),
);
final productsCacheProvider = Provider<ProductsCache>((ref) => ProductsCache());
