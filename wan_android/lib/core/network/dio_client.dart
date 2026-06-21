import 'package:dio/dio.dart';

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
    )..interceptors.add(LoggingInterceptor()); // 挂上日志拦截器（M8 再挂鉴权拦截器）
  }

  /// 单例（≈ URLSession.shared 那种全局唯一）。
  static final DioClient instance = DioClient._internal();

  late final Dio _dio;
  Dio get dio => _dio;
}
