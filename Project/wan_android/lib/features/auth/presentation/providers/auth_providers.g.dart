// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 登录态 ≈ 你 iOS 里的 SessionManager/AuthViewModel（单例、跨页共享，App 生命周期内常驻）。
///
/// M8 登录/登出是整替换，不需要计算旧列表；这不等于所有异步操作天然无竞态。
/// M7 维护演进将购物车/收藏/订单的初始化等待和修改互斥分开处理。

@ProviderFor(Auth)
final authProvider = AuthProvider._();

/// 登录态 ≈ 你 iOS 里的 SessionManager/AuthViewModel（单例、跨页共享，App 生命周期内常驻）。
///
/// M8 登录/登出是整替换，不需要计算旧列表；这不等于所有异步操作天然无竞态。
/// M7 维护演进将购物车/收藏/订单的初始化等待和修改互斥分开处理。
final class AuthProvider extends $AsyncNotifierProvider<Auth, User?> {
  /// 登录态 ≈ 你 iOS 里的 SessionManager/AuthViewModel（单例、跨页共享，App 生命周期内常驻）。
  ///
  /// M8 登录/登出是整替换，不需要计算旧列表；这不等于所有异步操作天然无竞态。
  /// M7 维护演进将购物车/收藏/订单的初始化等待和修改互斥分开处理。
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
/// M8 登录/登出是整替换，不需要计算旧列表；这不等于所有异步操作天然无竞态。
/// M7 维护演进将购物车/收藏/订单的初始化等待和修改互斥分开处理。

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
