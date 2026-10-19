import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/request_json.dart';
import '../domain/user.dart';
import 'login_response.dart';

/// M8 鉴权仓库，传输与解析在各自边界处理，≈ iOS SessionService。
class AuthRepository {
  final Dio _dio;
  // Dart 3.12 私有字段命名初始化参数，对外仍通过 dio: 注入。
  AuthRepository({required this._dio});
  Future<LoginResponse> login(String username, String password) async {
    try {
      return await requestJson(
        () => _dio.post(
          '/auth/login',
          data: {
            'username': username,
            'password': password,
            'expiresInMins': 30,
          },
        ),
        (data) => LoginResponse.fromJson(data as Map<String, dynamic>),
      );
    } on ServerException catch (error) {
      // M12 进阶：登录接口的 400/401 = 凭证错误（DummyJSON 对错误密码返回 400）。
      // 只在这里细化：其它接口的 401 是 token 失效，语义不同。
      if (error.code == 400 || error.code == 401) {
        throw const InvalidCredentialsException('用户名或密码错误');
      }
      rethrow;
    }
  }

  Future<User> fetchCurrentUser() => requestJson(
    () => _dio.get('/auth/me'),
    (data) => User.fromJson(data as Map<String, dynamic>),
  );
}
