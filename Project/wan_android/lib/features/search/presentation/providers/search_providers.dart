import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../products/domain/product.dart';
import '../../../products/presentation/providers/products_providers.dart';

part 'search_providers.g.dart';

/// 搜索结果（family：按关键词各自缓存，默认 autoDispose）。
/// 空关键词直接返回空列表、不发请求——省一次无意义的网络调用。
///
/// 注意：这里没有做防抖，防抖放在搜索页的 UI 层（用 Timer）。
/// 因为防抖是"输入节流"，属于交互层关注点；provider 只负责"给定关键词→拿结果"。
@riverpod
Future<List<Product>> searchResults(Ref ref, String query) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final page = await ref.watch(productsRepositoryProvider).searchProducts(q);
  return page.products;
}
