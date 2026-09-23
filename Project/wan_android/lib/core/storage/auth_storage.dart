import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// token 的安全存储 ≈ 你 iOS 里封装的 Keychain 读写器。
///
/// 对比 M7 的 CartStorage（用 shared_preferences，≈ UserDefaults）：
/// 1. token 是敏感凭证，明文存 UserDefaults/SharedPreferences 不安全，
///    所以这里换用 flutter_secure_storage——iOS 端底层就是直接用 Keychain 存的。
/// 2. CartStorage 只有 cart feature 自己用，放在 feature 内部就够了；
///    AuthStorage 则同时被 core/network 的 [AuthInterceptor]（读 token 拼请求头）
///    和 auth feature 的 Provider（登录成功写、登出清）两边用到，
///    "被多方共用" 是它该放 core/storage 而不是 features/auth/data 的原因。
class AuthStorage {
  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
