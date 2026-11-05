// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_info.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 应用版本号。
///
/// 用 provider 而不是全局常量，是为了演示"只读依赖"的注入方式：
/// 测试或多环境里可以用 override 换成别的值，而不用改调用方。

@ProviderFor(appVersion)
final appVersionProvider = AppVersionProvider._();

/// 应用版本号。
///
/// 用 provider 而不是全局常量，是为了演示"只读依赖"的注入方式：
/// 测试或多环境里可以用 override 换成别的值，而不用改调用方。

final class AppVersionProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// 应用版本号。
  ///
  /// 用 provider 而不是全局常量，是为了演示"只读依赖"的注入方式：
  /// 测试或多环境里可以用 override 换成别的值，而不用改调用方。
  AppVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appVersionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appVersionHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return appVersion(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$appVersionHash() => r'b634d00cfcfff6bca6de2443628d996155e81051';
