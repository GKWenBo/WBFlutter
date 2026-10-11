import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'auth_repository.dart';

/// 数据层装配入口；测试在这里替换依赖，页面状态只消费依赖。
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(dio: ref.watch(dioProvider)),
);
