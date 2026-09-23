import 'package:dio/dio.dart';

/// 构建 DummyJSON 专用 Dio（≈ 配好 baseURL/超时的 URLSession）。
/// 用工厂函数而非单例：谁需要谁构建、测试传 mock——
/// WanShop 的单例 DioClient 到 M4 也被改造成了可注入，这里直接一步到位。
Dio buildDio() {
  return Dio(
    BaseOptions(
      baseUrl: 'https://dummyjson.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json'},
    ),
  );
}
