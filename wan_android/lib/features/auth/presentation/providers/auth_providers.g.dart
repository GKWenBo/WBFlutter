// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(authStorage)
final authStorageProvider = AuthStorageProvider._();

final class AuthStorageProvider
    extends $FunctionalProvider<AuthStorage, AuthStorage, AuthStorage>
    with $Provider<AuthStorage> {
  AuthStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authStorageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authStorageHash();

  @$internal
  @override
  $ProviderElement<AuthStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthStorage create(Ref ref) {
    return authStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthStorage>(value),
    );
  }
}

String _$authStorageHash() => r'b3b9a28510aa45e76e975f0f4b21a3709371eb3b';

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'50a1d563eb512e3d26c62f7d6917fbcc58928eef';

/// 登录态 ≈ 你 iOS 里的 SessionManager/AuthViewModel（单例、跨页共享，App 生命周期内常驻）。
///
/// 和 M7 的 Cart 是同一种"AsyncNotifier + keepAlive"模式，但这里有个很好的对比：
/// Cart 的 mutation（加购/改数量）要在旧列表基础上"改一部分"，所以必须先 `await future`
/// 拿到最新值才能改，否则会有竞态覆盖；
/// 这里的 login()/logout() 是"整个替换掉旧状态"（不管旧值是什么，登录成功后就是新用户，
/// 登出后就是 null），不依赖旧状态，所以不需要 `await future` 这一步——
/// 是否要"先读旧值"取决于新状态是否依赖旧状态，而不是无脑套模板。

@ProviderFor(Auth)
final authProvider = AuthProvider._();

/// 登录态 ≈ 你 iOS 里的 SessionManager/AuthViewModel（单例、跨页共享，App 生命周期内常驻）。
///
/// 和 M7 的 Cart 是同一种"AsyncNotifier + keepAlive"模式，但这里有个很好的对比：
/// Cart 的 mutation（加购/改数量）要在旧列表基础上"改一部分"，所以必须先 `await future`
/// 拿到最新值才能改，否则会有竞态覆盖；
/// 这里的 login()/logout() 是"整个替换掉旧状态"（不管旧值是什么，登录成功后就是新用户，
/// 登出后就是 null），不依赖旧状态，所以不需要 `await future` 这一步——
/// 是否要"先读旧值"取决于新状态是否依赖旧状态，而不是无脑套模板。
final class AuthProvider extends $AsyncNotifierProvider<Auth, User?> {
  /// 登录态 ≈ 你 iOS 里的 SessionManager/AuthViewModel（单例、跨页共享，App 生命周期内常驻）。
  ///
  /// 和 M7 的 Cart 是同一种"AsyncNotifier + keepAlive"模式，但这里有个很好的对比：
  /// Cart 的 mutation（加购/改数量）要在旧列表基础上"改一部分"，所以必须先 `await future`
  /// 拿到最新值才能改，否则会有竞态覆盖；
  /// 这里的 login()/logout() 是"整个替换掉旧状态"（不管旧值是什么，登录成功后就是新用户，
  /// 登出后就是 null），不依赖旧状态，所以不需要 `await future` 这一步——
  /// 是否要"先读旧值"取决于新状态是否依赖旧状态，而不是无脑套模板。
  AuthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authHash();

  @$internal
  @override
  Auth create() => Auth();
}

String _$authHash() => r'2882b9be638bd6b9745e0ac18a7926a681433f5b';

/// 登录态 ≈ 你 iOS 里的 SessionManager/AuthViewModel（单例、跨页共享，App 生命周期内常驻）。
///
/// 和 M7 的 Cart 是同一种"AsyncNotifier + keepAlive"模式，但这里有个很好的对比：
/// Cart 的 mutation（加购/改数量）要在旧列表基础上"改一部分"，所以必须先 `await future`
/// 拿到最新值才能改，否则会有竞态覆盖；
/// 这里的 login()/logout() 是"整个替换掉旧状态"（不管旧值是什么，登录成功后就是新用户，
/// 登出后就是 null），不依赖旧状态，所以不需要 `await future` 这一步——
/// 是否要"先读旧值"取决于新状态是否依赖旧状态，而不是无脑套模板。

abstract class _$Auth extends $AsyncNotifier<User?> {
  FutureOr<User?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<User?>, User?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<User?>, User?>,
              AsyncValue<User?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
