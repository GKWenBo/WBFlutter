import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../../../shared/widgets/product_card.dart';
import '../state/cart_notifier.dart';
import '../state/search_notifier.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';
import 'product_list_page.dart';

/// 场景⑤：防抖 Timer/序号在 SearchNotifier 里，页面瘦成"转发 + 展示"。
/// searchProvider 是 autoDispose：页面 pop → 无人 watch → notifier 销毁，
/// ref.onDispose 挂的 Timer 清理一起执行——对照 v1/v2 的托管 dispose、
/// v3 的手动 Get.delete。TextEditingController 是纯 UI 状态，照旧住 State。
class V4SearchPage extends ConsumerStatefulWidget {
  const V4SearchPage({super.key});

  @override
  ConsumerState<V4SearchPage> createState() => _V4SearchPageState();
}

class _V4SearchPageState extends ConsumerState<V4SearchPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索商品（如 phone）',
            border: InputBorder.none,
          ),
          onChanged: ref.read(searchProvider.notifier).onQueryChanged,
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final count =
                  ref.watch(cartProvider.select((s) => s.totalCount));
              return CartIconButton(
                count: count,
                onPressed: () => pushWithScope(context, const V4CartPage()),
              );
            },
          ),
        ],
      ),
      body: state.query.isEmpty
          ? const Center(child: Text('输入关键词搜索'))
          : AsyncStateView(
              loading: state.status == SearchStatus.loading,
              error:
                  state.status == SearchStatus.failure ? state.error : null,
              onRetry: ref.read(searchProvider.notifier).retry,
              builder: (_) => state.results.isEmpty
                  ? const Center(child: Text('没有找到相关商品'))
                  : ListView.builder(
                      itemCount: state.results.length,
                      itemBuilder: (context, index) {
                        final product = state.results[index];
                        return ProductCard(
                          product: product,
                          onTap: () => pushWithScope(
                              context, V4ProductDetailPage(product: product)),
                          onAddToCart: () {
                            ref.read(cartProvider.notifier).add(product);
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(const SnackBar(
                                  content: Text('已加入购物车')));
                          },
                        );
                      },
                    ),
            ),
    );
  }
}
