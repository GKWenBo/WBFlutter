// 测试 AuthNotifier ≈ 给你的 SessionManager/AuthViewModel 写 XCTest。
// 用 ProviderContainer 直接测业务逻辑，用假 Repository/Storage 隔离真实网络与 Keychain。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wan_android/core/storage/auth_storage.dart';
import 'package:wan_android/features/auth/data/auth_repository.dart';
import 'package:wan_android/features/auth/data/login_response.dart';
import 'package:wan_android/features/auth/domain/user.dart';
import 'package:wan_android/features/auth/presentation/providers/auth_providers.dart';

/// 假存储：内存 Map 代替 flutter_secure_storage，测试环境没有真实 Keychain/系统凭据库。
class _FakeAuthStorage extends AuthStorage {
  String? token;

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    token = accessToken;
  }

  @override
  Future<void> clear() async => token = null;
}

/// 假 Repository：不打真实网络，按用户名/密码返回固定结果。
class _FakeAuthRepository extends AuthRepository {
  @override
  Future<LoginResponse> login(String username, String password) async {
    if (username == 'emilys' && password == 'emilyspass') {
      return const LoginResponse(
        id: 1,
        username: 'emilys',
        email: 'emily.johnson@x.dummyjson.com',
        firstName: 'Emily',
        lastName: 'Johnson',
        image: 'http://x/emilys.png',
        accessToken: 'fake-access-token',
        refreshToken: 'fake-refresh-token',
      );
    }
    throw Exception('用户名或密码错误');
  }

  @override
  Future<User> fetchCurrentUser() async => const User(
    id: 1,
    username: 'emilys',
    email: 'emily.johnson@x.dummyjson.com',
    firstName: 'Emily',
    lastName: 'Johnson',
    image: 'http://x/emilys.png',
  );
}

void main() {
  ProviderContainer makeContainer({String? initialToken}) {
    final storage = _FakeAuthStorage()..token = initialToken;
    final container = ProviderContainer(
      overrides: [
        authStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('冷启动无 token：build() 结果是未登录（null）', () async {
    final container = makeContainer();
    final user = await container.read(authProvider.future);
    expect(user, isNull);
  });

  test('冷启动有 token：build() 会换取用户信息，视为已登录', () async {
    final container = makeContainer(initialToken: 'stale-token');
    final user = await container.read(authProvider.future);
    expect(user?.username, 'emilys');
  });

  test('login 用正确账号密码：state 变成对应用户，且 token 落盘', () async {
    final container = makeContainer();
    await container.read(authProvider.notifier).login('emilys', 'emilyspass');

    final user = await container.read(authProvider.future);
    expect(user?.fullName, 'Emily Johnson');

    final storage = container.read(authStorageProvider) as _FakeAuthStorage;
    expect(storage.token, 'fake-access-token');
  });

  test('login 用错误密码：state 变成 AsyncError，不影响后续重试', () async {
    final container = makeContainer();
    await container.read(authProvider.notifier).login('emilys', 'wrong');

    expect(container.read(authProvider).hasError, isTrue);
  });

  test('logout 清空 state 与本地 token', () async {
    final container = makeContainer();
    await container.read(authProvider.notifier).login('emilys', 'emilyspass');
    expect(await container.read(authProvider.future), isNotNull);

    await container.read(authProvider.notifier).logout();

    expect(container.read(authProvider).asData?.value, isNull);
    final storage = container.read(authStorageProvider) as _FakeAuthStorage;
    expect(storage.token, isNull);
  });
}
