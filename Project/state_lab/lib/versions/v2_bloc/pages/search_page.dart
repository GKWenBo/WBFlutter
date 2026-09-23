import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../../../shared/widgets/product_card.dart';
import '../state/cart_cubit.dart';
import '../state/cart_state.dart';
import '../state/search_bloc.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';

/// 场景⑤：防抖/丢过期都进了 SearchBloc 的 EventTransformer，页面瘦成
/// "转发输入 + 展示状态"。用 BlocConsumer 演示 listener（副作用）与
/// builder（重建）分家：搜索失败时 listener 弹一个瞬时 SnackBar。
class V2SearchPage extends StatefulWidget {
  const V2SearchPage({super.key});

  @override
  State<V2SearchPage> createState() => _V2SearchPageState();
}

class _V2SearchPageState extends State<V2SearchPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openCart(BuildContext context) {
    final cart = context.read<CartCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BlocProvider.value(value: cart, child: const V2CartPage()),
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SearchBloc(context.read<ProductApi>()),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索商品（如 phone）',
                  border: InputBorder.none,
                ),
                onChanged: (text) =>
                    context.read<SearchBloc>().add(SearchQueryChanged(text)),
              ),
              actions: [
                BlocSelector<CartCubit, CartState, int>(
                  selector: (state) => state.totalCount,
                  builder: (context, count) => CartIconButton(
                    count: count,
                    onPressed: () => _openCart(context),
                  ),
                ),
              ],
            ),
            body: BlocConsumer<SearchBloc, SearchState>(
              // listener：副作用——失败弹瞬时 SnackBar（不参与重建）。
              // listenWhen 限定"刚转入 failure"才弹，避免重复。
              listenWhen: (prev, curr) =>
                  prev.status != curr.status &&
                  curr.status == SearchStatus.failure,
              listener: (context, state) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text(state.error ?? '搜索失败')),
                  );
              },
              builder: (context, state) => state.query.isEmpty
                  ? const Center(child: Text('输入关键词搜索'))
                  : AsyncStateView(
                      loading: state.status == SearchStatus.loading,
                      error: state.status == SearchStatus.failure
                          ? state.error
                          : null,
                      onRetry: () =>
                          context.read<SearchBloc>().add(const SearchRetried()),
                      builder: (_) => state.results.isEmpty
                          ? const Center(child: Text('没有找到相关商品'))
                          : ListView.builder(
                              itemCount: state.results.length,
                              itemBuilder: (context, index) {
                                final product = state.results[index];
                                return ProductCard(
                                  product: product,
                                  onTap: () => _openDetail(context, product),
                                  onAddToCart: () {
                                    context.read<CartCubit>().add(product);
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        const SnackBar(content: Text('已加入购物车')),
                                      );
                                  },
                                );
                              },
                            ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
