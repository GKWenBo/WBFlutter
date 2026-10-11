import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/auth_dependencies.dart';
import '../../domain/user.dart';

part 'auth_providers.g.dart';

/// 登录态 ≈ 你 iOS 里的 SessionManager/AuthViewModel（单例、跨页共享，App 生命周期内常驻）。
///
/// M8 登录/登出是整替换，不需要计算旧列表；这不等于所有异步操作天然无竞态。
/// M7 维护演进将购物车/收藏/订单的初始化等待和修改互斥分开处理。
@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  @override
  Future<User?> build() async {
    // 冷启动：先看本地有没有存过 token（≈ 你 iOS 里 App 启动时查一次 Keychain 决定要不要自动登录）。
    final String? token;
    try {
      token = await ref.read(authStorageProvider).readAccessToken();
    } catch (_) {
      return null; // 读取失败（如存储损坏）：当作未登录，不让 App 崩掉
    }
    if (token == null) return null;

    try {
      // 有 token 就换一次最新用户信息；AuthInterceptor 会自动把这个 token 拼进请求头。
      return await ref.read(authRepositoryProvider).fetchCurrentUser();
    } catch (_) {
      // token 可能已过期/失效：清掉本地凭证，回退到未登录态，而不是一直显示错误页。
      await ref.read(authStorageProvider).clear();
      return null;
    }
  }

  Future<void> login(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref
          .read(authRepositoryProvider)
          .login(username, password);
      await ref
          .read(authStorageProvider)
          .saveTokens(
            accessToken: result.accessToken,
            refreshToken: result.refreshToken,
          );
      return result.toUser();
    });
  }

  Future<void> logout() async {
    await ref.read(authStorageProvider).clear();
    state = const AsyncData(null);
  }
}
