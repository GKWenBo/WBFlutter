// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'products_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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

String _$productHash() => r'264fe914da3def72b1b73a6d83c8040cc6d54ea6';

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

/// M4 三态 + M9 离线兜底；维护演进：元信息进入状态，并隔离刷新代次。

@ProviderFor(ProductList)
final productListProvider = ProductListProvider._();

/// M4 三态 + M9 离线兜底；维护演进：元信息进入状态，并隔离刷新代次。
final class ProductListProvider
    extends $AsyncNotifierProvider<ProductList, ProductFeedState> {
  /// M4 三态 + M9 离线兜底；维护演进：元信息进入状态，并隔离刷新代次。
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

String _$productListHash() => r'183b89b773c811f6be3ecd17564e44699bc170c7';

/// M4 三态 + M9 离线兜底；维护演进：元信息进入状态，并隔离刷新代次。

abstract class _$ProductList extends $AsyncNotifier<ProductFeedState> {
  FutureOr<ProductFeedState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ProductFeedState>, ProductFeedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ProductFeedState>, ProductFeedState>,
              AsyncValue<ProductFeedState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
