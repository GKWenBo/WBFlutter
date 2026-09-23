import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../../../shared/widgets/product_card.dart';
import '../../../shared/widgets/rebuild_badge.dart';
import '../state/cart_notifier.dart';
import '../state/product_list_notifier.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';
import 'search_page.dart';

/// 跨路由的 riverpod 姿势：push 出的路由挂在 Navigator 下、不在 V4 的
/// ProviderScope 子树里——**Scope 这个入口毕竟还在树上**，所以要用
/// UncontrolledProviderScope 把同一个容器"再挂"到新路由头顶（它只引用
/// 不拥有，不会重复 dispose）。对照 v1/v2 的 `.value` re-provide：同一个
/// 问题、同一个思路，只是 re-provide 的是整个容器而不是单个对象；
/// 真实 App 把 ProviderScope 提到 MaterialApp 之上就根治了（S2 §5.6 的
/// 老答案，riverpod 世界同样适用）。
void pushWithScope(BuildContext context, Widget page) {
  final container = ProviderScope.containerOf(context);
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => UncontrolledProviderScope(container: container, child: page),
    ),
  );
}

/// 场景①：三态+分页。页面是 ConsumerWidget——build 多了个 ref，
/// watch 谁就订阅谁。没有任何 "create/..loadFirst()" 样板：AsyncNotifier
/// 的 build 就是首载，autoDispose 就是页面级生命周期。
class V4ProductListPage extends ConsumerWidget {
  const V4ProductListPage({super.key});

  bool _onScroll(WidgetRef ref, ScrollNotification notification) {
    if (notification.metrics.pixels >
        notification.metrics.maxScrollExtent - 200) {
      ref.read(productListProvider.notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productListProvider);
    final data = async.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniShop · v4 Riverpod'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () => pushWithScope(context, const V4SearchPage()),
          ),
          // select：字段级订阅——totalCount 没变，Consumer 不重建
          // （与 v1 的 context.select、v2 的 BlocSelector 同一粒度）。
          Consumer(
            builder: (context, ref, _) {
              final count =
                  ref.watch(cartProvider.select((s) => s.totalCount));
              return RebuildBadge(
                label: '列表角标',
                child: CartIconButton(
                  count: count,
                  onPressed: () => pushWithScope(context, const V4CartPage()),
                ),
              );
            },
          ),
        ],
      ),
      // AsyncValue 的三态直接喂给共享骨架：loading/error 不再是自维护字段
      body: AsyncStateView(
        loading: async.isLoading && data == null,
        error: data == null && async.hasError ? '加载失败：${async.error}' : null,
        onRetry: () => ref.invalidate(productListProvider),
        builder: (_) => RefreshIndicator(
          // refresh = invalidate + 等新一轮 build 的 future（内置的刷新语义）
          onRefresh: () => ref.refresh(productListProvider.future),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) => _onScroll(ref, n),
            child: ListView.builder(
              itemCount: data!.items.length + 1,
              itemBuilder: (context, index) {
                if (index == data.items.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: data.hasMore
                          ? const CircularProgressIndicator()
                          : const Text('没有更多了'),
                    ),
                  );
                }
                final product = data.items[index];
                return ProductCard(
                  product: product,
                  onTap: () => pushWithScope(
                      context, V4ProductDetailPage(product: product)),
                  onAddToCart: () {
                    ref.read(cartProvider.notifier).add(product);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                          const SnackBar(content: Text('已加入购物车')));
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
