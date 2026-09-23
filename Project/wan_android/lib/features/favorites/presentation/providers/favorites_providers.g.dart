// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorites_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(favoritesStorage)
final favoritesStorageProvider = FavoritesStorageProvider._();

final class FavoritesStorageProvider
    extends
        $FunctionalProvider<
          FavoritesStorage,
          FavoritesStorage,
          FavoritesStorage
        >
    with $Provider<FavoritesStorage> {
  FavoritesStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoritesStorageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoritesStorageHash();

  @$internal
  @override
  $ProviderElement<FavoritesStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FavoritesStorage create(Ref ref) {
    return favoritesStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FavoritesStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FavoritesStorage>(value),
    );
  }
}

String _$favoritesStorageHash() => r'6b5e3e4104dfd08ee5171269c033f0f4dee42f50';

/// 收藏列表的全局状态，与 Cart 同一套模式：
/// AsyncNotifier（初始值要异步读盘）+ keepAlive: true（跨页共享、活满 App 生命周期）。
/// M7 的两个教训（竞态用 `await future` 防、autoDispose 用 keepAlive 防）在这里原样适用。

@ProviderFor(Favorites)
final favoritesProvider = FavoritesProvider._();

/// 收藏列表的全局状态，与 Cart 同一套模式：
/// AsyncNotifier（初始值要异步读盘）+ keepAlive: true（跨页共享、活满 App 生命周期）。
/// M7 的两个教训（竞态用 `await future` 防、autoDispose 用 keepAlive 防）在这里原样适用。
final class FavoritesProvider
    extends $AsyncNotifierProvider<Favorites, List<Product>> {
  /// 收藏列表的全局状态，与 Cart 同一套模式：
  /// AsyncNotifier（初始值要异步读盘）+ keepAlive: true（跨页共享、活满 App 生命周期）。
  /// M7 的两个教训（竞态用 `await future` 防、autoDispose 用 keepAlive 防）在这里原样适用。
  FavoritesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoritesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoritesHash();

  @$internal
  @override
  Favorites create() => Favorites();
}

String _$favoritesHash() => r'f66813714f3de1a69441ad98b95c9a274c227bf0';

/// 收藏列表的全局状态，与 Cart 同一套模式：
/// AsyncNotifier（初始值要异步读盘）+ keepAlive: true（跨页共享、活满 App 生命周期）。
/// M7 的两个教训（竞态用 `await future` 防、autoDispose 用 keepAlive 防）在这里原样适用。

abstract class _$Favorites extends $AsyncNotifier<List<Product>> {
  FutureOr<List<Product>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Product>>, List<Product>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Product>>, List<Product>>,
              AsyncValue<List<Product>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 派生 + family 的组合："某个商品是否已收藏"。
///
/// 详情页的♥按钮 watch 它：isFavoriteProvider(product.id)。
/// 它 watch 整个收藏列表，列表一变，**只有关心这个 id 的那个实例**会重新计算并通知
/// 自己的订阅者——比让详情页直接 watch 整个 favoritesProvider 再自己 contains 更精准，
/// 也把"怎么判断已收藏"这条逻辑收拢到一处（UI 里不散落 contains 判断）。

@ProviderFor(isFavorite)
final isFavoriteProvider = IsFavoriteFamily._();

/// 派生 + family 的组合："某个商品是否已收藏"。
///
/// 详情页的♥按钮 watch 它：isFavoriteProvider(product.id)。
/// 它 watch 整个收藏列表，列表一变，**只有关心这个 id 的那个实例**会重新计算并通知
/// 自己的订阅者——比让详情页直接 watch 整个 favoritesProvider 再自己 contains 更精准，
/// 也把"怎么判断已收藏"这条逻辑收拢到一处（UI 里不散落 contains 判断）。

final class IsFavoriteProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// 派生 + family 的组合："某个商品是否已收藏"。
  ///
  /// 详情页的♥按钮 watch 它：isFavoriteProvider(product.id)。
  /// 它 watch 整个收藏列表，列表一变，**只有关心这个 id 的那个实例**会重新计算并通知
  /// 自己的订阅者——比让详情页直接 watch 整个 favoritesProvider 再自己 contains 更精准，
  /// 也把"怎么判断已收藏"这条逻辑收拢到一处（UI 里不散落 contains 判断）。
  IsFavoriteProvider._({
    required IsFavoriteFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'isFavoriteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isFavoriteHash();

  @override
  String toString() {
    return r'isFavoriteProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as int;
    return isFavorite(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IsFavoriteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isFavoriteHash() => r'8ed7ee384768385f5d7fb8717a0b94c9f4be2efb';

/// 派生 + family 的组合："某个商品是否已收藏"。
///
/// 详情页的♥按钮 watch 它：isFavoriteProvider(product.id)。
/// 它 watch 整个收藏列表，列表一变，**只有关心这个 id 的那个实例**会重新计算并通知
/// 自己的订阅者——比让详情页直接 watch 整个 favoritesProvider 再自己 contains 更精准，
/// 也把"怎么判断已收藏"这条逻辑收拢到一处（UI 里不散落 contains 判断）。

final class IsFavoriteFamily extends $Family
    with $FunctionalFamilyOverride<bool, int> {
  IsFavoriteFamily._()
    : super(
        retry: null,
        name: r'isFavoriteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 派生 + family 的组合："某个商品是否已收藏"。
  ///
  /// 详情页的♥按钮 watch 它：isFavoriteProvider(product.id)。
  /// 它 watch 整个收藏列表，列表一变，**只有关心这个 id 的那个实例**会重新计算并通知
  /// 自己的订阅者——比让详情页直接 watch 整个 favoritesProvider 再自己 contains 更精准，
  /// 也把"怎么判断已收藏"这条逻辑收拢到一处（UI 里不散落 contains 判断）。

  IsFavoriteProvider call(int productId) =>
      IsFavoriteProvider._(argument: productId, from: this);

  @override
  String toString() => r'isFavoriteProvider';
}

/// 派生：收藏总数（"我的"页菜单行上显示）。写法呼应 cartTotalCount。

@ProviderFor(favoritesCount)
final favoritesCountProvider = FavoritesCountProvider._();

/// 派生：收藏总数（"我的"页菜单行上显示）。写法呼应 cartTotalCount。

final class FavoritesCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// 派生：收藏总数（"我的"页菜单行上显示）。写法呼应 cartTotalCount。
  FavoritesCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoritesCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoritesCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return favoritesCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$favoritesCountHash() => r'd88bf16d5755f4ef6637af44224ad5e687d5fe9b';
