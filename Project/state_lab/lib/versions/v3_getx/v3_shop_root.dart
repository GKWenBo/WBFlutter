import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../shared/api/dio_client.dart';
import '../../shared/api/product_api.dart';
import 'pages/product_list_page.dart';
import 'state/cart_getx_controller.dart';

/// v3 状态根。对照 v1/v2 最扎眼的一点：**这里没有任何 "Provider" 挂树**——
/// GetX 的依赖住在一张全局注册表（`Get.put`/`Get.find`），和 Widget 树
/// 完全无关。跨路由因此零 re-provide（v1/v2 每条 push 的 `.value` 全删了），
/// 页面在任何地方 `Get.find` 都能拿到。
///
/// 便利的账单：依赖不跟树走，**生命周期也不跟树走**——退出版本必须手动
/// `Get.delete`，否则下次进来读到旧购物车、五个版本互相污染（我们没用
/// GetMaterialApp，路由绑定的 smart management 不存在；就算用了，这种
/// "版本级"依赖也得手动管）。这个 StatefulWidget 的全部职责就是这对
/// put/delete——树上一个壳，管着树外一张表。
class V3ShopRoot extends StatefulWidget {
  const V3ShopRoot({super.key, this.api});

  /// 可注入的 API（测试传 Fake；生产走 DummyJSON）。
  final ProductApi? api;

  @override
  State<V3ShopRoot> createState() => _V3ShopRootState();
}

class _V3ShopRootState extends State<V3ShopRoot> {
  @override
  void initState() {
    super.initState();
    Get.put<ProductApi>(widget.api ?? ProductApi(buildDio()));
    Get.put<CartGetxController>(CartGetxController());
  }

  @override
  void dispose() {
    Get.delete<CartGetxController>(force: true);
    Get.delete<ProductApi>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const V3ProductListPage();
}
