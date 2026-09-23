import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../../../shared/widgets/product_card.dart';
import '../state/cart_getx_controller.dart';
import '../state/search_getx_controller.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';

/// 场景⑤：防抖在 debounce worker、丢过期在序号，页面瘦成"转发 + 展示"。
/// 页面级 controller 的生命周期：没有 GetMaterialApp 的 smart management，
/// 就老老实实 initState 里 Get.put、dispose 里 Get.delete——GetX 的托管
/// 便利大半绑在它的路由体系上，不用它的路由就得自己管（技术文档专节）。
class V3SearchPage extends StatefulWidget {
  const V3SearchPage({super.key});

  @override
  State<V3SearchPage> createState() => _V3SearchPageState();
}

class _V3SearchPageState extends State<V3SearchPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    Get.put<SearchGetxController>(SearchGetxController(Get.find()));
  }

  @override
  void dispose() {
    _controller.dispose();
    Get.delete<SearchGetxController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartGetxController>();
    final search = Get.find<SearchGetxController>();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索商品（如 phone）',
            border: InputBorder.none,
          ),
          onChanged: search.onQueryChanged,
        ),
        actions: [
          Obx(
            () => CartIconButton(
              count: cart.totalCount,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const V3CartPage()),
              ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (search.query.value.trim().isEmpty) {
          return const Center(child: Text('输入关键词搜索'));
        }
        return AsyncStateView(
          loading: search.loading.value,
          error: search.error.value,
          onRetry: search.retry,
          builder: (_) => search.results.isEmpty
              ? const Center(child: Text('没有找到相关商品'))
              : ListView.builder(
                  itemCount: search.results.length,
                  itemBuilder: (context, index) {
                    final product = search.results[index];
                    return ProductCard(
                      product: product,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              V3ProductDetailPage(product: product),
                        ),
                      ),
                      onAddToCart: () {
                        cart.add(product);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                              const SnackBar(content: Text('已加入购物车')));
                      },
                    );
                  },
                ),
        );
      }),
    );
  }
}
