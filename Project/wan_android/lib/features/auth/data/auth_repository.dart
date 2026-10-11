import 'package:dio/dio.dart';

import '../../../core/network/request_json.dart';
import '../domain/user.dart';
import 'login_response.dart';

/// M8 鉴权仓库，传输与解析在各自边界处理，≈ iOS SessionService。
class AuthRepository {
  final Dio _dio;
  // Dart 3.12 私有字段命名初始化参数，对外仍通过 dio: 注入。
  AuthRepository({required this._dio});
  Future<LoginResponse> login(String username, String password) => requestJson(
    () => _dio.post(
      '/auth/login',
      data: {'username': username, 'password': password, 'expiresInMins': 30},
    ),
    (data) => LoginResponse.fromJson(data as Map<String, dynamic>),
  );
  Future<User> fetchCurrentUser() => requestJson(
    () => _dio.get('/auth/me'),
    (data) => User.fromJson(data as Map<String, dynamic>),
  );
}
