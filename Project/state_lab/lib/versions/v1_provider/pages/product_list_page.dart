import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../../../shared/widgets/product_card.dart';
import '../../../shared/widgets/rebuild_badge.dart';
import '../state/cart_model.dart';
import '../state/product_list_model.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';
import 'search_page.dart';

/// 场景①：三态+分页——状态在 ProductListModel，页面只剩装配。
/// 对照 v0：整页 Stateless；页面级 provider 让模型生命周期 = 本页
/// 生命周期（pop 即 dispose，托管的，不用记）。
class V1ProductListPage extends StatelessWidget {
  const V1ProductListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // create 的 context 在本页之上，能 read 到根上的 ProductApi。
      // 级联 ..loadFirst()：创建即开载（≈ v0 的 initState 首载）。
      create: (context) =>
          ProductListModel(context.read<ProductApi>())..loadFirst(),
      child: const _ListScaffold(),
    );
  }
}

class _ListScaffold extends StatelessWidget {
  const _ListScaffold();

  void _openCart(BuildContext context) {
    // 跨路由 re-provide：S1 手写的那行，官方 API 叫 .value——
    // 已有实例复用用 .value，新建托管用 create（经典面试题）。
    final cart = context.read<CartModel>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: cart,
          child: const V1CartPage(),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, Product product) {
    final cart = context.read<CartModel>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: cart,
          child: V1ProductDetailPage(product: product),
        ),
      ),
    );
  }

  void _openSearch(BuildContext context) {
    // 搜索页要 api + cart 两样：MultiProvider 打包带过去。
    final cart = context.read<CartModel>();
    final api = context.read<ProductApi>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiProvider(
          providers: [
            Provider<ProductApi>.value(value: api),
            ChangeNotifierProvider<CartModel>.value(value: cart),
          ],
          child: const V1SearchPage(),
        ),
      ),
    );
  }

  bool _onScroll(BuildContext context, ScrollNotification notification) {
    if (notification.metrics.pixels >
        notification.metrics.maxScrollExtent - 200) {
      context.read<ProductListModel>().loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniShop · v1 Provider'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () => _openSearch(context),
          ),
          // Selector：S1"Builder 圈依赖"的强化版——依赖从"对象"收窄到
          // "字段"：totalCount 的值没变（==），哪怕 notifyListeners 开火
          // 也不重建。S1 只能裁块，Selector 能裁字段。
          Selector<CartModel, int>(
            selector: (_, cart) => cart.totalCount,
            builder: (context, count, _) => RebuildBadge(
              label: '列表角标',
              child: CartIconButton(
                count: count,
                onPressed: () => _openCart(context),
              ),
            ),
          ),
        ],
      ),
      // Consumer = "of() + Builder"的官方合体；第三个参数 child 用于
      // 缓存不依赖 model 的大子树（本页用不上，示意见技术文档）。
      body: Consumer<ProductListModel>(
        builder: (context, model, _) => AsyncStateView(
          loading: model.loading && model.items.isEmpty,
          error: model.items.isEmpty ? model.error : null,
          onRetry: model.loadFirst,
          builder: (_) => RefreshIndicator(
            onRefresh: model.loadFirst,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) => _onScroll(context, n),
              child: ListView.builder(
                itemCount: model.items.length + 1,
                itemBuilder: (context, index) {
                  if (index == model.items.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: model.hasMore
                            ? const CircularProgressIndicator()
                            : const Text('没有更多了'),
                      ),
                    );
                  }
                  final product = model.items[index];
                  return ProductCard(
                    product: product,
                    onTap: () => _openDetail(context, product),
                    onAddToCart: () {
                      context.read<CartModel>().add(product);
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
      ),
    );
  }
}
