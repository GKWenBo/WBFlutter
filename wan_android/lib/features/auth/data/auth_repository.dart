import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/dio_client.dart';
import '../domain/user.dart';
import 'login_response.dart';

/// 鉴权数据仓库，和 M3 的 ProductsRepository 是同一种写法：
/// UI/Provider 只调这里的方法，不直接碰 dio。
class AuthRepository {
  final Dio _dio;

  AuthRepository({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  /// 用账号密码换 token。DummyJSON 的 `/auth/login` 不需要提前带 token（未登录状态发起）。
  Future<LoginResponse> login(String username, String password) async {
    try {
      final res = await _dio.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
          'expiresInMins': 30,
        },
      );
      return LoginResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    } catch (e) {
      throw ParseException('登录响应解析失败：$e');
    }
  }

  /// 用当前 token 换用户信息。这次请求依赖 [AuthInterceptor] 自动加的 Authorization 头，
  /// 调用方不用自己拼 token——这正是拦截器统一处理横切关注点的意义。
  Future<User> fetchCurrentUser() async {
    try {
      final res = await _dio.get('/auth/me');
      return User.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    } catch (e) {
      throw ParseException('用户信息解析失败：$e');
    }
  }
}
