import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/dio_client.dart';
import '../../shared/api/product_api.dart';
import 'pages/product_list_page.dart';
import 'state/api_provider.dart';

/// v4 状态根。ProviderScope = riverpod 的容器入口：provider 图本身是
/// 树外的顶层常量，但**每个 Scope 一套独立的实例容器**——挂在版本根上
/// 意味着退出版本容器销毁、状态清零，五版本互不污染（真实单方案 App
/// 通常把 ProviderScope 包在 runApp 最外层，那时"容器=App 生命周期"）。
/// 生产/测试的 ProductApi 都从 overrides 注入——同一个口子（对照 v1/v2
/// 的构造参数注入、v3 的 Get.put 注入）。
class V4ShopRoot extends StatelessWidget {
  const V4ShopRoot({super.key, this.api});

  /// 可注入的 API（测试传 Fake；生产走 DummyJSON）。
  final ProductApi? api;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        productApiProvider.overrideWithValue(api ?? ProductApi(buildDio())),
      ],
      child: const V4ProductListPage(),
    );
  }
}
