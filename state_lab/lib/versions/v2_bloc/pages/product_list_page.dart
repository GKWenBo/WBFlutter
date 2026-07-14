import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../../../shared/widgets/product_card.dart';
import '../../../shared/widgets/rebuild_badge.dart';
import '../state/cart_cubit.dart';
import '../state/cart_state.dart';
import '../state/product_list_bloc.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';
import 'search_page.dart';

/// 场景①：三态+分页——状态在 ProductListBloc，页面只剩装配。
/// 对照 v1：ChangeNotifierProvider(create:..loadFirst()) → BlocProvider
/// (create:..add(Started()))。生命周期同样托管：pop 即 close。
class V2ProductListPage extends StatelessWidget {
  const V2ProductListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ProductListBloc(context.read<ProductApi>())..add(ProductListStarted()),
      child: const _ListScaffold(),
    );
  }
}

class _ListScaffold extends StatelessWidget {
  const _ListScaffold();

  void _openCart(BuildContext context) {
    // 跨路由 re-provide：v1 的 .value，bloc 版叫 BlocProvider.value——
    // 同一条铁律（已有实例复用用 .value，新建托管用 create）。
    final cart = context.read<CartCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(value: cart, child: const V2CartPage()),
      ),
    );
  }

  void _openDetail(BuildContext context, Product product) {
    final cart = context.read<CartCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cart,
          child: V2ProductDetailPage(product: product),
        ),
      ),
    );
  }

  void _openSearch(BuildContext context) {
    final cart = context.read<CartCubit>();
    final api = context.read<ProductApi>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiRepositoryProvider(
          providers: [RepositoryProvider<ProductApi>.value(value: api)],
          child: BlocProvider.value(value: cart, child: const V2SearchPage()),
        ),
      ),
    );
  }

  bool _onScroll(BuildContext context, ScrollNotification notification) {
    if (notification.metrics.pixels > notification.metrics.maxScrollExtent - 200) {
      context.read<ProductListBloc>().add(ProductListLoadMore());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniShop · v2 Bloc'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () => _openSearch(context),
          ),
          // BlocSelector：v1 Selector 的 bloc 版——从 CartState 里选出
          // totalCount(int)，值没变就不重建。角标只吃这一个标量。
          BlocSelector<CartCubit, CartState, int>(
            selector: (state) => state.totalCount,
            builder: (context, count) => RebuildBadge(
              label: '列表角标',
              child:
                  CartIconButton(count: count, onPressed: () => _openCart(context)),
            ),
          ),
        ],
      ),
      body: BlocBuilder<ProductListBloc, ProductListState>(
        // buildWhen：加载更多时 loadingMore 翻转不该重建整列表——只有
        // items/status/error 变了才重建 body。v1 Consumer 没这道闸，
        // 这是 Bloc 给的字段级收窄（对照 tech doc §4）。
        buildWhen: (prev, curr) =>
            prev.items != curr.items ||
            prev.status != curr.status ||
            prev.error != curr.error,
        builder: (context, state) => AsyncStateView(
          loading: state.status == ListStatus.loading && state.items.isEmpty,
          error: state.items.isEmpty && state.status == ListStatus.failure
              ? state.error
              : null,
          onRetry: () => context.read<ProductListBloc>().add(ProductListStarted()),
          builder: (_) => RefreshIndicator(
            onRefresh: () async {
              final bloc = context.read<ProductListBloc>();
              bloc.add(ProductListRefreshed());
              await bloc.stream.firstWhere((s) => s.status != ListStatus.loading);
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) => _onScroll(context, n),
              child: ListView.builder(
                itemCount: state.items.length + 1,
                itemBuilder: (context, index) {
                  if (index == state.items.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: state.hasMore
                            ? const CircularProgressIndicator()
                            : const Text('没有更多了'),
                      ),
                    );
                  }
                  final product = state.items[index];
                  return ProductCard(
                    product: product,
                    onTap: () => _openDetail(context, product),
                    onAddToCart: () {
                      context.read<CartCubit>().add(product);
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(const SnackBar(content: Text('已加入购物车')));
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
