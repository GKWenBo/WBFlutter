// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 搜索结果（family：按关键词各自缓存，默认 autoDispose）。
/// 空关键词直接返回空列表、不发请求——省一次无意义的网络调用。
///
/// 注意：这里没有做防抖，防抖放在搜索页的 UI 层（用 Timer）。
/// 因为防抖是"输入节流"，属于交互层关注点；provider 只负责"给定关键词→拿结果"。

@ProviderFor(searchResults)
final searchResultsProvider = SearchResultsFamily._();

/// 搜索结果（family：按关键词各自缓存，默认 autoDispose）。
/// 空关键词直接返回空列表、不发请求——省一次无意义的网络调用。
///
/// 注意：这里没有做防抖，防抖放在搜索页的 UI 层（用 Timer）。
/// 因为防抖是"输入节流"，属于交互层关注点；provider 只负责"给定关键词→拿结果"。

final class SearchResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Product>>,
          List<Product>,
          FutureOr<List<Product>>
        >
    with $FutureModifier<List<Product>>, $FutureProvider<List<Product>> {
  /// 搜索结果（family：按关键词各自缓存，默认 autoDispose）。
  /// 空关键词直接返回空列表、不发请求——省一次无意义的网络调用。
  ///
  /// 注意：这里没有做防抖，防抖放在搜索页的 UI 层（用 Timer）。
  /// 因为防抖是"输入节流"，属于交互层关注点；provider 只负责"给定关键词→拿结果"。
  SearchResultsProvider._({
    required SearchResultsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'searchResultsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$searchResultsHash();

  @override
  String toString() {
    return r'searchResultsProvider'
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
    return searchResults(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchResultsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchResultsHash() => r'7000544f1522bd1836bb422fb4a7d2a911008cd0';

/// 搜索结果（family：按关键词各自缓存，默认 autoDispose）。
/// 空关键词直接返回空列表、不发请求——省一次无意义的网络调用。
///
/// 注意：这里没有做防抖，防抖放在搜索页的 UI 层（用 Timer）。
/// 因为防抖是"输入节流"，属于交互层关注点；provider 只负责"给定关键词→拿结果"。

final class SearchResultsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Product>>, String> {
  SearchResultsFamily._()
    : super(
        retry: null,
        name: r'searchResultsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 搜索结果（family：按关键词各自缓存，默认 autoDispose）。
  /// 空关键词直接返回空列表、不发请求——省一次无意义的网络调用。
  ///
  /// 注意：这里没有做防抖，防抖放在搜索页的 UI 层（用 Timer）。
  /// 因为防抖是"输入节流"，属于交互层关注点；provider 只负责"给定关键词→拿结果"。

  SearchResultsProvider call(String query) =>
      SearchResultsProvider._(argument: query, from: this);

  @override
  String toString() => r'searchResultsProvider';
}
