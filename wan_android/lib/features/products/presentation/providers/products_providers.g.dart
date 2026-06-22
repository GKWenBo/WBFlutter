// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'products_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 提供 ProductsRepository（依赖注入）。
/// 任何地方 `ref.watch(productsRepositoryProvider)` 都能拿到同一个；
/// 测试时可以 `overrideWith` 换成 mock（这就是 Riverpod 自带的 DI 能力）。

@ProviderFor(productsRepository)
final productsRepositoryProvider = ProductsRepositoryProvider._();

/// 提供 ProductsRepository（依赖注入）。
/// 任何地方 `ref.watch(productsRepositoryProvider)` 都能拿到同一个；
/// 测试时可以 `overrideWith` 换成 mock（这就是 Riverpod 自带的 DI 能力）。

final class ProductsRepositoryProvider
    extends
        $FunctionalProvider<
          ProductsRepository,
          ProductsRepository,
          ProductsRepository
        >
    with $Provider<ProductsRepository> {
  /// 提供 ProductsRepository（依赖注入）。
  /// 任何地方 `ref.watch(productsRepositoryProvider)` 都能拿到同一个；
  /// 测试时可以 `overrideWith` 换成 mock（这就是 Riverpod 自带的 DI 能力）。
  ProductsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'productsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$productsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProductsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProductsRepository create(Ref ref) {
    return productsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProductsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProductsRepository>(value),
    );
  }
}

String _$productsRepositoryHash() =>
    r'834631e4e78a070de6c6ebc1f3c7ca848a85a01b';

@ProviderFor(product)
final productProvider = ProductFamily._();

final class ProductProvider
    extends $FunctionalProvider<AsyncValue<Product>, Product, FutureOr<Product>>
    with $FutureModifier<Product>, $FutureProvider<Product> {
  ProductProvider._({
    required ProductFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'productProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$productHash();

  @override
  String toString() {
    return r'productProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Product> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Product> create(Ref ref) {
    final argument = this.argument as int;
    return product(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProductProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$productHash() => r'679b81b4327bac40c01f8adcba602711a92a2921';

final class ProductFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Product>, int> {
  ProductFamily._()
    : super(
        retry: null,
        name: r'productProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProductProvider call(int id) => ProductProvider._(argument: id, from: this);

  @override
  String toString() => r'productProvider';
}

/// 商品列表的状态管理 ≈ 你 iOS 的 ViewModel（MVVM）。
///
/// build() 返回一个 Future，Riverpod 会自动把它包成 AsyncValue：
/// 请求中 → loading，成功 → data，抛错 → error。页面只管 .when 渲染，不用自己记 loading 标志。

@ProviderFor(ProductList)
final productListProvider = ProductListProvider._();

/// 商品列表的状态管理 ≈ 你 iOS 的 ViewModel（MVVM）。
///
/// build() 返回一个 Future，Riverpod 会自动把它包成 AsyncValue：
/// 请求中 → loading，成功 → data，抛错 → error。页面只管 .when 渲染，不用自己记 loading 标志。
final class ProductListProvider
    extends $AsyncNotifierProvider<ProductList, List<Product>> {
  /// 商品列表的状态管理 ≈ 你 iOS 的 ViewModel（MVVM）。
  ///
  /// build() 返回一个 Future，Riverpod 会自动把它包成 AsyncValue：
  /// 请求中 → loading，成功 → data，抛错 → error。页面只管 .when 渲染，不用自己记 loading 标志。
  ProductListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'productListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$productListHash();

  @$internal
  @override
  ProductList create() => ProductList();
}

String _$productListHash() => r'5f1fecbfde64c8db778d6250ed29a976d5c5ad24';

/// 商品列表的状态管理 ≈ 你 iOS 的 ViewModel（MVVM）。
///
/// build() 返回一个 Future，Riverpod 会自动把它包成 AsyncValue：
/// 请求中 → loading，成功 → data，抛错 → error。页面只管 .when 渲染，不用自己记 loading 标志。

abstract class _$ProductList extends $AsyncNotifier<List<Product>> {
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
