// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// M12 国际化进阶：App 内手动选择的语言。null = 跟随系统。
///
/// 和收藏/购物车同一套模式（AsyncNotifier + keepAlive + 串行队列 + 保存成功才发布）：
/// - AsyncNotifier：初始值要异步读盘；
/// - keepAlive：MaterialApp 一直 watch 它，语言是整个 App 生命周期的全局状态；
/// - 保存成功才发布：如果磁盘写失败还把界面切成德语，下次启动又变回中文，用户会以为 App 抽风。
///
/// iOS 对照：iOS 13+ 的"每 App 语言"由系统设置页管理，App 只能读；
/// Flutter 这里是 App 自己管 —— MaterialApp.locale 一换，整棵树按新语言重建。
/// （两者并不冲突：Info.plist 声明了 CFBundleLocalizations 后，
///  用户在 iOS 设置里给 App 选的语言会作为"系统语言"传进来，被这里的 null 分支采用。）

@ProviderFor(AppLocale)
final appLocaleProvider = AppLocaleProvider._();

/// M12 国际化进阶：App 内手动选择的语言。null = 跟随系统。
///
/// 和收藏/购物车同一套模式（AsyncNotifier + keepAlive + 串行队列 + 保存成功才发布）：
/// - AsyncNotifier：初始值要异步读盘；
/// - keepAlive：MaterialApp 一直 watch 它，语言是整个 App 生命周期的全局状态；
/// - 保存成功才发布：如果磁盘写失败还把界面切成德语，下次启动又变回中文，用户会以为 App 抽风。
///
/// iOS 对照：iOS 13+ 的"每 App 语言"由系统设置页管理，App 只能读；
/// Flutter 这里是 App 自己管 —— MaterialApp.locale 一换，整棵树按新语言重建。
/// （两者并不冲突：Info.plist 声明了 CFBundleLocalizations 后，
///  用户在 iOS 设置里给 App 选的语言会作为"系统语言"传进来，被这里的 null 分支采用。）
final class AppLocaleProvider
    extends $AsyncNotifierProvider<AppLocale, Locale?> {
  /// M12 国际化进阶：App 内手动选择的语言。null = 跟随系统。
  ///
  /// 和收藏/购物车同一套模式（AsyncNotifier + keepAlive + 串行队列 + 保存成功才发布）：
  /// - AsyncNotifier：初始值要异步读盘；
  /// - keepAlive：MaterialApp 一直 watch 它，语言是整个 App 生命周期的全局状态；
  /// - 保存成功才发布：如果磁盘写失败还把界面切成德语，下次启动又变回中文，用户会以为 App 抽风。
  ///
  /// iOS 对照：iOS 13+ 的"每 App 语言"由系统设置页管理，App 只能读；
  /// Flutter 这里是 App 自己管 —— MaterialApp.locale 一换，整棵树按新语言重建。
  /// （两者并不冲突：Info.plist 声明了 CFBundleLocalizations 后，
  ///  用户在 iOS 设置里给 App 选的语言会作为"系统语言"传进来，被这里的 null 分支采用。）
  AppLocaleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLocaleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLocaleHash();

  @$internal
  @override
  AppLocale create() => AppLocale();
}

String _$appLocaleHash() => r'e631590014f5039be902ba56b00aa886716f31d2';

/// M12 国际化进阶：App 内手动选择的语言。null = 跟随系统。
///
/// 和收藏/购物车同一套模式（AsyncNotifier + keepAlive + 串行队列 + 保存成功才发布）：
/// - AsyncNotifier：初始值要异步读盘；
/// - keepAlive：MaterialApp 一直 watch 它，语言是整个 App 生命周期的全局状态；
/// - 保存成功才发布：如果磁盘写失败还把界面切成德语，下次启动又变回中文，用户会以为 App 抽风。
///
/// iOS 对照：iOS 13+ 的"每 App 语言"由系统设置页管理，App 只能读；
/// Flutter 这里是 App 自己管 —— MaterialApp.locale 一换，整棵树按新语言重建。
/// （两者并不冲突：Info.plist 声明了 CFBundleLocalizations 后，
///  用户在 iOS 设置里给 App 选的语言会作为"系统语言"传进来，被这里的 null 分支采用。）

abstract class _$AppLocale extends $AsyncNotifier<Locale?> {
  FutureOr<Locale?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Locale?>, Locale?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Locale?>, Locale?>,
              AsyncValue<Locale?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
