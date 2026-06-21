import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 自定义日志拦截器：把每个请求/响应/错误打到控制台。
/// ≈ iOS 里你写的 URLProtocol / 网络日志中间件 / OkHttp Interceptor。
///
/// 一个拦截器有三个钩子，对应一次请求的三个时机：
///   onRequest  发出前 —— 统一加 header、token（M8 鉴权会用到）
///   onResponse 收到后 —— 统一剥壳、记录耗时
///   onError    出错时 —— 统一转换错误、重试
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('➡️  ${options.method} ${options.uri}');
    handler.next(options); // 必须放行，否则请求被"吞掉"永远发不出去
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('✅  ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('❌  ${err.type} ${err.requestOptions.uri} -> ${err.message}');
    handler.next(err); // 放行给上层（repository）去翻译成 AppException
  }
}
