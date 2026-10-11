// 跨模块业务能力入口，内部实现不属于模块契约。
export 'data/orders_dependencies.dart' show addressStorageProvider;
export 'presentation/providers/orders_providers.dart'
    show ordersProvider, ordersCountProvider, savedAddressProvider;
