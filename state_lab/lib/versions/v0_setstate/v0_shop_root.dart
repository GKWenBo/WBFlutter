import 'package:flutter/material.dart';

import '../../shared/api/dio_client.dart';
import '../../shared/api/product_api.dart';
import 'pages/product_list_page.dart';
import 'state/cart_controller.dart';
import 'state/mini_provider.dart';

/// v0 状态根（S1 就地重构版）：共享状态从"裸 List + 回调森林"收编为
/// CartController，由 MiniProvider 挂到树上——子孙自取自订阅，
/// 根不再当快递中转站。层层传参原版见 git 历史 93abcd2。
class V0ShopRoot extends StatefulWidget {
  const V0ShopRoot({super.key, this.api});

  /// 可注入的 API（测试传 Fake；生产走 DummyJSON）。
  final ProductApi? api;

  @override
  State<V0ShopRoot> createState() => _V0ShopRootState();
}

class _V0ShopRootState extends State<V0ShopRoot> {
  late final ProductApi _api = widget.api ?? ProductApi(buildDio());

  /// 控制器生命周期归根管（≈ 根 VC 持有 viewModel，deinit 一起走）。
  final CartController _cart = CartController();

  @override
  void dispose() {
    _cart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ 这层 MiniProvider 只罩得住本路由的子树（列表页）。
    // detail/cart/search 是 push 出去的兄弟路由，不在这棵 Element 树里，
    // 往上找不到它——所以每条 push 要用同一个 _cart 再包一层（见各页 _openXxx）。
    // 这是 InheritedWidget 的著名边界：查找走 Element 父链，不跨路由。
    return MiniProvider(
      notifier: _cart,
      child: V0ProductListPage(api: _api),
    );
  }
}
