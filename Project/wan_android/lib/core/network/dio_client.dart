import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_env.dart';
import '../storage/auth_storage.dart';
import 'auth_interceptor.dart';
import 'logging_interceptor.dart';

/// M3 → M4 维护演进：共享客户端由 ProviderScope 拥有，≈ 注入 URLSession。
/// 测试 override 安全存储后，登录逻辑和拦截器读写的是同一个实例。
final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());
final dioProvider = Provider<Dio>((ref) {
  final env = AppEnv.current;
  final dio = Dio(
    BaseOptions(
      baseUrl: env.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json'},
    ),
  )..interceptors.add(AuthInterceptor(ref.watch(authStorageProvider)));
  if (env.enableLogging) dio.interceptors.add(LoggingInterceptor());
  ref.onDispose(() => dio.close(force: true));
  return dio;
});
