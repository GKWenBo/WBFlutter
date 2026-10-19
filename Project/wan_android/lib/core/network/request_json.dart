import 'package:dio/dio.dart';

import '../error/failure.dart';

/// M3：网络错误只在网络边界翻译，解析错误只在解码边界翻译。
Future<T> requestJson<T>(
  Future<Response<dynamic>> Function() request,
  T Function(dynamic) decode,
) async {
  final Response<dynamic> response;
  try {
    response = await request();
  } on DioException catch (error) {
    throw mapDioException(error);
  }
  try {
    return decode(response.data);
  } on FormatException catch (error) {
    throw ParseException('数据解析失败：$error');
  } on TypeError catch (error) {
    throw ParseException('数据格式不符合预期：$error');
  }
}

AppException mapDioException(DioException error) {
  // Dio Transformer 会在 Repository 解码前解析 JSON，并包装其 FormatException。
  if (error.type == DioExceptionType.unknown &&
      error.error is FormatException) {
    return const ParseException('响应 JSON 格式不正确');
  }
  // M12：这里的中文只是开发者诊断信息；用户看到的文案由 UI 按类型 + issue 翻译。
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const NetworkException(
      '网络超时',
      issue: NetworkIssue.timeout,
    ),
    DioExceptionType.connectionError => const NetworkException(
      '无法连接服务器',
      issue: NetworkIssue.unreachable,
    ),
    DioExceptionType.badResponse => ServerException(
      '服务器开小差了（${error.response?.statusCode}）',
      code: error.response?.statusCode,
    ),
    _ => const UnknownException('请求未能完成，请稍后重试'),
  };
}
