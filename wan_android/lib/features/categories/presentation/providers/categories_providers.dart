import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../products/domain/product.dart';
import '../../../products/presentation/providers/products_providers.dart';
import '../../domain/category.dart';

part 'categories_providers.g.dart';

/// 分类列表。
/// 分类数据很少变 → 用 keepAlive 常驻缓存：切走再切回这个 Tab 不会重新请求。
/// （对比：不加 keepAlive 的代码生成 provider 默认是 autoDispose，没人看就清掉。）
@Riverpod(keepAlive: true)
Future<List<Category>> categories(Ref ref) {
  return ref.watch(productsRepositoryProvider).fetchCategories();
}

/// 某个分类下的商品（family：按 slug 各自缓存）。
/// 默认 autoDispose：离开该分类页面后自动清理，避免缓存无限膨胀。
@riverpod
Future<List<Product>> categoryProducts(Ref ref, String slug) async {
  final page = await ref.watch(productsRepositoryProvider).fetchByCategory(slug);
  return page.products;
}
