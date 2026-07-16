import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../../../shared/widgets/product_card.dart';
import '../../../shared/widgets/rebuild_badge.dart';
import '../state/cart_getx_controller.dart';
import '../state/product_list_getx_controller.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';
import 'search_page.dart';

/// 场景①：三态+分页，**手动挡**页面。外层 GetBuilder 只当 init 宿主
/// （创建 controller + autoRemove 托管销毁，controller 从不发无 id 的
/// update()，所以这层永不重建）；真正吃通知的是 body 的 id:'list' 和
/// footer 的 id:'footer' 两个 GetBuilder——重建范围手工点名。
class V3ProductListPage extends StatelessWidget {
  const V3ProductListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ProductListGetxController>(
      init: ProductListGetxController(Get.find<ProductApi>()),
      builder: (_) => const _ListScaffold(),
    );
  }
}

class _ListScaffold extends StatelessWidget {
  const _ListScaffold();

  // 对照 v1/v2 的 _openCart：没有 .value re-provide！目标页自己 Get.find。
  void _openCart(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const V3CartPage()),
    );
  }

  void _openDetail(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => V3ProductDetailPage(product: product),
      ),
    );
  }

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const V3SearchPage()),
    );
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.pixels >
        notification.metrics.maxScrollExtent - 200) {
      Get.find<ProductListGetxController>().loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cart = Get.find<CartGetxController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniShop · v3 GetX'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () => _openSearch(context),
          ),
          // Obx：自动挡的最小重建单元——闭包里读了哪个 Rx 就订阅哪个。
          // totalCount 遍历 RxList 即完成订阅登记（对照 Selector/BlocSelector
          // 要手写 selector，Obx 的依赖收集是隐式的）。
          Obx(
            () => RebuildBadge(
              label: '列表角标',
              child: CartIconButton(
                count: cart.totalCount,
                onPressed: () => _openCart(context),
              ),
            ),
          ),
        ],
      ),
      body: GetBuilder<ProductListGetxController>(
        id: 'list', // 只认 update(['list'])——手动挡的 buildWhen
        builder: (c) => AsyncStateView(
          loading: c.loading && c.items.isEmpty,
          error: c.items.isEmpty ? c.error : null,
          onRetry: c.loadFirst,
          builder: (_) => RefreshIndicator(
            onRefresh: c.loadFirst,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: ListView.builder(
                itemCount: c.items.length + 1,
                itemBuilder: (context, index) {
                  if (index == c.items.length) {
                    // footer 单独一个 id：loadingMore 翻转只刷这里
                    return GetBuilder<ProductListGetxController>(
                      id: 'footer',
                      builder: (c) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: c.hasMore
                              ? const CircularProgressIndicator()
                              : const Text('没有更多了'),
                        ),
                      ),
                    );
                  }
                  final product = c.items[index];
                  return ProductCard(
                    product: product,
                    onTap: () => _openDetail(context, product),
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
            ),
          ),
        ),
      ),
    );
  }
}
