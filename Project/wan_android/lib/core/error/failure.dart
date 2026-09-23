import 'package:dio/dio.dart';

/// 统一的应用层异常 ≈ 你 iOS 里把 URLSession/解码 各种底层错误归一成的一个 enum。
///
/// 用 sealed class（呼应 M2 学的）：子类就这几种，UI/repository 可以用穷尽 switch 处理，
/// 编译器保证你不会漏掉某种错误态。
sealed class AppException implements Exception {
  final String message; // 给用户看的"人话"
  const AppException(this.message);

  @override
  String toString() => message;

  /// 把 dio 的底层异常翻译成"人话"的应用异常。
  /// ≈ 你把 URLError.code 映射成业务可读错误。
  factory AppException.fromDio(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const NetworkException('网络超时，请稍后重试'),
      DioExceptionType.connectionError => const NetworkException('无法连接服务器，请检查网络'),
      DioExceptionType.badResponse => ServerException(
        '服务器开小差了（${e.response?.statusCode}）',
        code: e.response?.statusCode,
      ),
      _ => UnknownException('出错了：${e.message ?? '未知错误'}'),
    };
  }
}

/// 网络层错误：超时、断网、连不上。
class NetworkException extends AppException {
  const NetworkException(super.message);
}

/// 服务器返回非 2xx（4xx/5xx）。
class ServerException extends AppException {
  final int? code;
  const ServerException(super.message, {this.code});
}

/// 解析/数据格式错误。
class ParseException extends AppException {
  const ParseException(super.message);
}

/// 兜底未知错误。
class UnknownException extends AppException {
  const UnknownException(super.message);
}
