import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/error_messages.dart';
import '../../../core/widgets/error_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../products/ui.dart';
import 'providers/categories_providers.dart';

/// 某分类下的商品页。slug 决定请求哪个分类，title 只用于导航栏展示。
///
/// M12：标题优先按 slug 用**当前语言**翻译（首页快捷入口的那几个分类有翻译）；
/// 没有翻译的（分类页列出的服务端分类名）才用路由传进来的 title。
class CategoryProductsPage extends ConsumerWidget {
  final String slug;
  final String title;

  const CategoryProductsPage({
    super.key,
    required this.slug,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // family：按 slug 取对应分类的商品（autoDispose，离开自动清）。
    final async = ref.watch(categoryProductsProvider(slug));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizedCategoryName(l10n, slug) ?? title)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: l10n.describeError(e),
          onRetry: () => ref.invalidate(categoryProductsProvider(slug)),
        ),
        data: (products) => ProductGrid(products: products),
      ),
    );
  }
}
