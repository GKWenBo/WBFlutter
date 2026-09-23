// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'orders_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ordersStorage)
final ordersStorageProvider = OrdersStorageProvider._();

final class OrdersStorageProvider
    extends $FunctionalProvider<OrdersStorage, OrdersStorage, OrdersStorage>
    with $Provider<OrdersStorage> {
  OrdersStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ordersStorageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ordersStorageHash();

  @$internal
  @override
  $ProviderElement<OrdersStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OrdersStorage create(Ref ref) {
    return ordersStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OrdersStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OrdersStorage>(value),
    );
  }
}

String _$ordersStorageHash() => r'00f23647981ac0404bc3591346b96c959dd3147c';

@ProviderFor(addressStorage)
final addressStorageProvider = AddressStorageProvider._();

final class AddressStorageProvider
    extends $FunctionalProvider<AddressStorage, AddressStorage, AddressStorage>
    with $Provider<AddressStorage> {
  AddressStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'addressStorageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$addressStorageHash();

  @$internal
  @override
  $ProviderElement<AddressStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AddressStorage create(Ref ref) {
    return addressStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AddressStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AddressStorage>(value),
    );
  }
}

String _$addressStorageHash() => r'9868284d5b2bd04bc9ddee7e63f19cd182740099';

/// 上次保存的默认地址（结算页用来预填表单）。
/// 一次性异步读取，没有"修改后要通知谁"的需求，所以一个函数 provider 就够，
/// 不用 Notifier——下单成功后 invalidate 一下让它下次重读即可。

@ProviderFor(savedAddress)
final savedAddressProvider = SavedAddressProvider._();

/// 上次保存的默认地址（结算页用来预填表单）。
/// 一次性异步读取，没有"修改后要通知谁"的需求，所以一个函数 provider 就够，
/// 不用 Notifier——下单成功后 invalidate 一下让它下次重读即可。

final class SavedAddressProvider
    extends
        $FunctionalProvider<
          AsyncValue<ShippingAddress?>,
          ShippingAddress?,
          FutureOr<ShippingAddress?>
        >
    with $FutureModifier<ShippingAddress?>, $FutureProvider<ShippingAddress?> {
  /// 上次保存的默认地址（结算页用来预填表单）。
  /// 一次性异步读取，没有"修改后要通知谁"的需求，所以一个函数 provider 就够，
  /// 不用 Notifier——下单成功后 invalidate 一下让它下次重读即可。
  SavedAddressProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedAddressProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedAddressHash();

  @$internal
  @override
  $FutureProviderElement<ShippingAddress?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ShippingAddress?> create(Ref ref) {
    return savedAddress(ref);
  }
}

String _$savedAddressHash() => r'a0ab6d5f51a4e6cbd49ef4c6b5d0c0788530ce31';

/// 订单列表：第三个 AsyncNotifier + keepAlive（Cart/Favorites/Orders 同一模式，
/// 到这里你应该已经能把这套"异步初始化的全局状态"当模板默写了）。

@ProviderFor(Orders)
final ordersProvider = OrdersProvider._();

/// 订单列表：第三个 AsyncNotifier + keepAlive（Cart/Favorites/Orders 同一模式，
/// 到这里你应该已经能把这套"异步初始化的全局状态"当模板默写了）。
final class OrdersProvider extends $AsyncNotifierProvider<Orders, List<Order>> {
  /// 订单列表：第三个 AsyncNotifier + keepAlive（Cart/Favorites/Orders 同一模式，
  /// 到这里你应该已经能把这套"异步初始化的全局状态"当模板默写了）。
  OrdersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ordersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ordersHash();

  @$internal
  @override
  Orders create() => Orders();
}

String _$ordersHash() => r'0339f3bf6615f499fb6fb0662c80086b2a0ff6be';

/// 订单列表：第三个 AsyncNotifier + keepAlive（Cart/Favorites/Orders 同一模式，
/// 到这里你应该已经能把这套"异步初始化的全局状态"当模板默写了）。

abstract class _$Orders extends $AsyncNotifier<List<Order>> {
  FutureOr<List<Order>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Order>>, List<Order>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Order>>, List<Order>>,
              AsyncValue<List<Order>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 派生：订单数（"我的"页菜单行显示），写法同 favoritesCount。

@ProviderFor(ordersCount)
final ordersCountProvider = OrdersCountProvider._();

/// 派生：订单数（"我的"页菜单行显示），写法同 favoritesCount。

final class OrdersCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// 派生：订单数（"我的"页菜单行显示），写法同 favoritesCount。
  OrdersCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ordersCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ordersCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return ordersCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$ordersCountHash() => r'faa8b1f2dc8f87a58328c9c41b2a64f268f2fb09';
