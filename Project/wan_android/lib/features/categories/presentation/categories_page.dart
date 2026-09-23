import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/error_view.dart';
import 'providers/categories_providers.dart';

/// 分类页：列出所有分类，点进去看该分类商品。
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCategories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('分类')),
      body: asyncCategories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
        data: (categories) => ListView.separated(
          itemCount: categories.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final c = categories[i];
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
