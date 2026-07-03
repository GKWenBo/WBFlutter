import 'package:dio/dio.dart';

import '../storage/auth_storage.dart';
import 'auth_interceptor.dart';
import 'logging_interceptor.dart';

/// 全局 Dio 实例（≈ 你封装的 URLSession + 默认配置）。
///
/// 现在用最简单的单例；M4 会改成由 Riverpod 提供，
/// 这样测试时能轻松替换成 mock 的 Dio（依赖注入）。
class DioClient {
  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://dummyjson.com', // 所有请求的公共前缀
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Accept': 'application/json'},
      ),
    )..interceptors.addAll([
        AuthInterceptor(AuthStorage()), // 先加 token（M8）
        LoggingInterceptor(), // 再打日志，日志里能看到最终带没带 Authorization 头
      ]);
  }

  /// 单例（≈ URLSession.shared 那种全局唯一）。
  static final DioClient instance = DioClient._internal();

  late final Dio _dio;
  Dio get dio => _dio;
}
