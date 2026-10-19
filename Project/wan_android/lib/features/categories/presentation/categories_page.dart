import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/error_messages.dart';
import '../../../core/widgets/error_view.dart';
import '../../../l10n/app_localizations.dart';
import 'providers/categories_providers.dart';

/// 分类页：列出所有分类，点进去看该分类商品。
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCategories = ref.watch(categoriesProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.categoriesTitle)),
      body: asyncCategories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: l10n.describeError(e),
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
        data: (categories) => ListView.separated(
          itemCount: categories.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final c = categories[i];
            // 分类名来自服务端（DummyJSON 只有英文），不在 ARB 里——
            // "服务端内容"的多语言要靠后端按 Accept-Language 返回，App 侧翻不了（M12 讲义有展开）。
            return ListTile(
              leading: CircleAvatar(
                child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?'),
              ),
              title: Text(
                c.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              // 跳分类商品页：slug 进路径，展示名通过 extra 传（不进 URL）。
              onTap: () => context.push('/category/${c.slug}', extra: c.name),
            );
          },
        ),
      ),
    );
  }
}
