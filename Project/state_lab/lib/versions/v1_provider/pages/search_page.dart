import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../../../shared/widgets/product_card.dart';
import '../state/cart_model.dart';
import '../state/search_model.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';

/// 场景⑤：防抖/序号都搬进了 SearchModel，页面瘦成"转发 + 展示"。
/// TextEditingController 是纯 UI 状态，留在 State（要 dispose）。
class V1SearchPage extends StatefulWidget {
  const V1SearchPage({super.key});

  @override
  State<V1SearchPage> createState() => _V1SearchPageState();
}

class _V1SearchPageState extends State<V1SearchPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openCart(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // 页面级 provider：SearchModel 生命周期 = 本页（dispose 托管，
      // 里面的 Timer 也随之 cancel——对照 v0 页面手动 dispose）。
      create: (context) => SearchModel(context.read<ProductApi>()),
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '搜索商品（如 phone）',
                border: InputBorder.none,
              ),
              onChanged: context.read<SearchModel>().onQueryChanged,
            ),
            actions: [
              Selector<CartModel, int>(
                selector: (_, cart) => cart.totalCount,
                builder: (context, count, _) => CartIconButton(
                  count: count,
                  onPressed: () => _openCart(context),
                ),
              ),
            ],
          ),
          body: Consumer<SearchModel>(
            builder: (context, model, _) => model.lastQuery.isEmpty
                ? const Center(child: Text('输入关键词搜索'))
                : AsyncStateView(
                    loading: model.loading,
                    error: model.error,
                    onRetry: model.retry,
                    builder: (_) => model.results.isEmpty
                        ? const Center(child: Text('没有找到相关商品'))
                        : ListView.builder(
                            itemCount: model.results.length,
                            itemBuilder: (context, index) {
                              final product = model.results[index];
                              return ProductCard(
                                product: product,
                                onTap: () => _openDetail(context, product),
                                onAddToCart: () {
                                  context.read<CartModel>().add(product);
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(const SnackBar(
                                        content: Text('已加入购物车')));
                                },
                              );
                            },
                          ),
                  ),
          ),
        );
      }),
    );
  }
}
