import 'package:dio/dio.dart';

import '../config/app_env.dart';
import '../storage/auth_storage.dart';
import 'auth_interceptor.dart';
import 'logging_interceptor.dart';

/// 全局 Dio 实例（≈ 你封装的 URLSession + 默认配置）。
///
/// 现在用最简单的单例；M4 会改成由 Riverpod 提供，
/// 这样测试时能轻松替换成 mock 的 Dio（依赖注入）。
class DioClient {
  DioClient._internal() {
    final env = AppEnv.current;
    _dio = Dio(
      BaseOptions(
        baseUrl: env.baseUrl, // M12：域名按 Flavor 走（真实项目 dev/staging/prod 各一套）
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Accept': 'application/json'},
      ),
    )..interceptors.add(AuthInterceptor(AuthStorage())); // 先加 token（M8）

    // M12：网络日志只在开启的环境挂（prod 关掉，避免刷屏 + 泄露请求细节）。
    if (env.enableLogging) {
      _dio.interceptors.add(LoggingInterceptor());
    }
  }

  /// 单例（≈ URLSession.shared 那种全局唯一）。
  static final DioClient instance = DioClient._internal();

  late final Dio _dio;
  Dio get dio => _dio;
}
