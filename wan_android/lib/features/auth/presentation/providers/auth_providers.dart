import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/storage/auth_storage.dart';
import '../../data/auth_repository.dart';
import '../../domain/user.dart';

part 'auth_providers.g.dart';

@riverpod
AuthStorage authStorage(Ref ref) => AuthStorage();

@riverpod
AuthRepository authRepository(Ref ref) => AuthRepository();

/// 登录态 ≈ 你 iOS 里的 SessionManager/AuthViewModel（单例、跨页共享，App 生命周期内常驻）。
///
/// 和 M7 的 Cart 是同一种"AsyncNotifier + keepAlive"模式，但这里有个很好的对比：
/// Cart 的 mutation（加购/改数量）要在旧列表基础上"改一部分"，所以必须先 `await future`
/// 拿到最新值才能改，否则会有竞态覆盖；
/// 这里的 login()/logout() 是"整个替换掉旧状态"（不管旧值是什么，登录成功后就是新用户，
/// 登出后就是 null），不依赖旧状态，所以不需要 `await future` 这一步——
/// 是否要"先读旧值"取决于新状态是否依赖旧状态，而不是无脑套模板。
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
      final result = await ref.read(authRepositoryProvider).login(
        username,
        password,
      );
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
