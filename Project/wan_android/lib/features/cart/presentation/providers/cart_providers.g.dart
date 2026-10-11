// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 购物车状态 ≈ 你 iOS 里的 CartViewModel（单例、跨页共享）。
///
/// 用 AsyncNotifier（而不是同步 Notifier）：初始值要从磁盘异步读取，
/// 这和 M4 的 ProductList 是同一种模式——只是这里的"异步数据源"是本地存储而不是网络。
///
/// 关键教训 1（真实踩过的坑）：如果初始读盘和"加购"各自独立地异步跑，
/// 迟到的读盘结果可能用"读盘那一刻的旧数据"覆盖掉刚加购的新数据（竞态条件）。
/// M7 维护演进：`await future` 等待初始化，串行队列才保证多个修改互斥。
/// 保存成功后发布状态，调用方能可靠判断操作是否完成。
///
/// 关键教训 2：代码生成的 provider 默认是 autoDispose——没人 watch 时会被回收。
/// 购物车这种"全局唯一、该活满整个 App 生命周期"的状态不能靠"正好有人在 watch"这种偶然性
/// 兜底（万一某个异步方法还没跑完、最后一个监听者恰好被移除，state= 会因 provider 已销毁而报错）。
/// 所以显式标 keepAlive: true，常驻不回收（呼应 M6 的 categoriesProvider）。

@ProviderFor(Cart)
final cartProvider = CartProvider._();

/// 购物车状态 ≈ 你 iOS 里的 CartViewModel（单例、跨页共享）。
///
/// 用 AsyncNotifier（而不是同步 Notifier）：初始值要从磁盘异步读取，
/// 这和 M4 的 ProductList 是同一种模式——只是这里的"异步数据源"是本地存储而不是网络。
///
/// 关键教训 1（真实踩过的坑）：如果初始读盘和"加购"各自独立地异步跑，
/// 迟到的读盘结果可能用"读盘那一刻的旧数据"覆盖掉刚加购的新数据（竞态条件）。
/// M7 维护演进：`await future` 等待初始化，串行队列才保证多个修改互斥。
/// 保存成功后发布状态，调用方能可靠判断操作是否完成。
///
/// 关键教训 2：代码生成的 provider 默认是 autoDispose——没人 watch 时会被回收。
/// 购物车这种"全局唯一、该活满整个 App 生命周期"的状态不能靠"正好有人在 watch"这种偶然性
/// 兜底（万一某个异步方法还没跑完、最后一个监听者恰好被移除，state= 会因 provider 已销毁而报错）。
/// 所以显式标 keepAlive: true，常驻不回收（呼应 M6 的 categoriesProvider）。
final class CartProvider extends $AsyncNotifierProvider<Cart, List<CartItem>> {
  /// 购物车状态 ≈ 你 iOS 里的 CartViewModel（单例、跨页共享）。
  ///
  /// 用 AsyncNotifier（而不是同步 Notifier）：初始值要从磁盘异步读取，
  /// 这和 M4 的 ProductList 是同一种模式——只是这里的"异步数据源"是本地存储而不是网络。
  ///
  /// 关键教训 1（真实踩过的坑）：如果初始读盘和"加购"各自独立地异步跑，
  /// 迟到的读盘结果可能用"读盘那一刻的旧数据"覆盖掉刚加购的新数据（竞态条件）。
  /// M7 维护演进：`await future` 等待初始化，串行队列才保证多个修改互斥。
  /// 保存成功后发布状态，调用方能可靠判断操作是否完成。
  ///
  /// 关键教训 2：代码生成的 provider 默认是 autoDispose——没人 watch 时会被回收。
  /// 购物车这种"全局唯一、该活满整个 App 生命周期"的状态不能靠"正好有人在 watch"这种偶然性
  /// 兜底（万一某个异步方法还没跑完、最后一个监听者恰好被移除，state= 会因 provider 已销毁而报错）。
  /// 所以显式标 keepAlive: true，常驻不回收（呼应 M6 的 categoriesProvider）。
  CartProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cartProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cartHash();

  @$internal
  @override
  Cart create() => Cart();
}

String _$cartHash() => r'2c4b40d0ba06d849af0e5d69fcb6b928cb155dbc';

/// 购物车状态 ≈ 你 iOS 里的 CartViewModel（单例、跨页共享）。
///
/// 用 AsyncNotifier（而不是同步 Notifier）：初始值要从磁盘异步读取，
/// 这和 M4 的 ProductList 是同一种模式——只是这里的"异步数据源"是本地存储而不是网络。
///
/// 关键教训 1（真实踩过的坑）：如果初始读盘和"加购"各自独立地异步跑，
/// 迟到的读盘结果可能用"读盘那一刻的旧数据"覆盖掉刚加购的新数据（竞态条件）。
/// M7 维护演进：`await future` 等待初始化，串行队列才保证多个修改互斥。
/// 保存成功后发布状态，调用方能可靠判断操作是否完成。
///
/// 关键教训 2：代码生成的 provider 默认是 autoDispose——没人 watch 时会被回收。
/// 购物车这种"全局唯一、该活满整个 App 生命周期"的状态不能靠"正好有人在 watch"这种偶然性
/// 兜底（万一某个异步方法还没跑完、最后一个监听者恰好被移除，state= 会因 provider 已销毁而报错）。
/// 所以显式标 keepAlive: true，常驻不回收（呼应 M6 的 categoriesProvider）。

abstract class _$Cart extends $AsyncNotifier<List<CartItem>> {
  FutureOr<List<CartItem>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<CartItem>>, List<CartItem>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<CartItem>>, List<CartItem>>,
              AsyncValue<List<CartItem>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 派生 provider：购物车总件数（用于 Tab 角标）。
/// 用 .asData?.value（Riverpod 3.x 用法，呼应 M4）：还在 loading/error 时先当空列表算，
/// 磁盘读取通常一瞬间完成，用户几乎不会看到角标"闪一下 0"。

@ProviderFor(cartTotalCount)
final cartTotalCountProvider = CartTotalCountProvider._();

/// 派生 provider：购物车总件数（用于 Tab 角标）。
/// 用 .asData?.value（Riverpod 3.x 用法，呼应 M4）：还在 loading/error 时先当空列表算，
/// 磁盘读取通常一瞬间完成，用户几乎不会看到角标"闪一下 0"。

final class CartTotalCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// 派生 provider：购物车总件数（用于 Tab 角标）。
  /// 用 .asData?.value（Riverpod 3.x 用法，呼应 M4）：还在 loading/error 时先当空列表算，
  /// 磁盘读取通常一瞬间完成，用户几乎不会看到角标"闪一下 0"。
  CartTotalCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cartTotalCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cartTotalCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return cartTotalCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$cartTotalCountHash() => r'deeadb34041ae160d42b0a9c0e1b0a6ecd9ac4c3';

/// 派生 provider：购物车总金额。

@ProviderFor(cartTotalPrice)
final cartTotalPriceProvider = CartTotalPriceProvider._();

/// 派生 provider：购物车总金额。

final class CartTotalPriceProvider
    extends $FunctionalProvider<double, double, double>
    with $Provider<double> {
  /// 派生 provider：购物车总金额。
  CartTotalPriceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cartTotalPriceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cartTotalPriceHash();

  @$internal
  @override
  $ProviderElement<double> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  double create(Ref ref) {
    return cartTotalPrice(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$cartTotalPriceHash() => r'58bbd4b48c8bd60cfb5d962e1261b3112db19227';
