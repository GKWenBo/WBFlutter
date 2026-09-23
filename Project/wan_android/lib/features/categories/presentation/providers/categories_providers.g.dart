// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'categories_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 分类列表。
/// 分类数据很少变 → 用 keepAlive 常驻缓存：切走再切回这个 Tab 不会重新请求。
/// （对比：不加 keepAlive 的代码生成 provider 默认是 autoDispose，没人看就清掉。）

@ProviderFor(categories)
final categoriesProvider = CategoriesProvider._();

/// 分类列表。
/// 分类数据很少变 → 用 keepAlive 常驻缓存：切走再切回这个 Tab 不会重新请求。
/// （对比：不加 keepAlive 的代码生成 provider 默认是 autoDispose，没人看就清掉。）

final class CategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Category>>,
          List<Category>,
          FutureOr<List<Category>>
        >
    with $FutureModifier<List<Category>>, $FutureProvider<List<Category>> {
  /// 分类列表。
  /// 分类数据很少变 → 用 keepAlive 常驻缓存：切走再切回这个 Tab 不会重新请求。
  /// （对比：不加 keepAlive 的代码生成 provider 默认是 autoDispose，没人看就清掉。）
  CategoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoriesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoriesHash();

  @$internal
  @override
  $FutureProviderElement<List<Category>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Category>> create(Ref ref) {
    return categories(ref);
  }
}

String _$categoriesHash() => r'4c1f71dca0f5065ec5e0eab4680b3a7e69091b54';

/// 某个分类下的商品（family：按 slug 各自缓存）。
/// 默认 autoDispose：离开该分类页面后自动清理，避免缓存无限膨胀。

@ProviderFor(categoryProducts)
final categoryProductsProvider = CategoryProductsFamily._();

/// 某个分类下的商品（family：按 slug 各自缓存）。
/// 默认 autoDispose：离开该分类页面后自动清理，避免缓存无限膨胀。

final class CategoryProductsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Product>>,
          List<Product>,
          FutureOr<List<Product>>
        >
    with $FutureModifier<List<Product>>, $FutureProvider<List<Product>> {
  /// 某个分类下的商品（family：按 slug 各自缓存）。
  /// 默认 autoDispose：离开该分类页面后自动清理，避免缓存无限膨胀。
  CategoryProductsProvider._({
    required CategoryProductsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'categoryProductsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$categoryProductsHash();

  @override
  String toString() {
    return r'categoryProductsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Product>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Product>> create(Ref ref) {
    final argument = this.argument as String;
    return categoryProducts(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CategoryProductsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$categoryProductsHash() => r'47b88e311ae46281f976f6bb1d69d36f7647bab2';

/// 某个分类下的商品（family：按 slug 各自缓存）。
/// 默认 autoDispose：离开该分类页面后自动清理，避免缓存无限膨胀。

final class CategoryProductsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Product>>, String> {
  CategoryProductsFamily._()
    : super(
        retry: null,
        name: r'categoryProductsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 某个分类下的商品（family：按 slug 各自缓存）。
  /// 默认 autoDispose：离开该分类页面后自动清理，避免缓存无限膨胀。

  CategoryProductsProvider call(String slug) =>
      CategoryProductsProvider._(argument: slug, from: this);

  @override
  String toString() => r'categoryProductsProvider';
}
