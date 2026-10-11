import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'categories_repository.dart';

/// 数据层装配入口；测试在这里替换依赖，页面状态只消费依赖。
final categoriesRepositoryProvider = Provider<CategoriesRepository>(
  (ref) => CategoriesRepository(dio: ref.watch(dioProvider)),
);
