import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/api/dio_client.dart';
import '../../shared/api/product_api.dart';
import 'pages/product_list_page.dart';
import 'state/cart_model.dart';

/// v1 状态根。对照 S1：StatefulWidget 宿主（创建/dispose/挂树三件事）
/// 整个消失——create/dispose 由 ChangeNotifierProvider 托管，这就是
/// "Provider 帮你干的脏活"第一条。根自己瘦成 StatelessWidget。
/// `Provider<ProductApi>` 是纯 DI（不监听不通知）：服务对象也走树，
/// 页面连 api 构造参数都不用要了。
class V1ShopRoot extends StatelessWidget {
  const V1ShopRoot({super.key, this.api});

  /// 可注入的 API（测试传 Fake；生产走 DummyJSON）。
  final ProductApi? api;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ProductApi>(create: (_) => api ?? ProductApi(buildDio())),
        ChangeNotifierProvider<CartModel>(create: (_) => CartModel()),
      ],
      child: const V1ProductListPage(),
    );
  }
}
