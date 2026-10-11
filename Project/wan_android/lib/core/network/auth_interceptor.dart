import 'package:dio/dio.dart';

import '../storage/auth_storage.dart';

/// 自动带 token 的拦截器 ≈ 你 iOS 里给 URLRequest 统一加 `Authorization` header 的那层。
///
/// onRequest 允许写成 async 方法：不必同步返回，dio 会一直等到你调用 handler.next()/reject()
/// 才真正发出请求——这就是"异步地读一次 Keychain，再决定要不要加 header"能成立的原因。
class AuthInterceptor extends Interceptor {
  final AuthStorage _storage;

  AuthInterceptor(this._storage);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _storage.readAccessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    } catch (error, stackTrace) {
      // Keychain 失败必须结束拦截器链，不把异常遗留在 async void 回调。
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          message: '无法读取登录凭证',
        ),
      );
    }
  }
}
