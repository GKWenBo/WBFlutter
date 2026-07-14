import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/api/dio_client.dart';
import '../../shared/api/product_api.dart';
import 'pages/product_list_page.dart';
import 'state/cart_cubit.dart';

/// v2 状态根。对照 v1：MultiProvider → 这里用 RepositoryProvider(纯 DI，
/// bloc 世界管"数据来源/服务"的惯用件) + BlocProvider(管 Cubit/Bloc)。
/// CartCubit 版本级共享（挂在根，跨页存活）；ProductApi 走 Repository
/// 下发，页面级 Bloc 在 create 里 read 它。
class V2ShopRoot extends StatelessWidget {
  const V2ShopRoot({super.key, this.api});

  final ProductApi? api;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ProductApi>(
      create: (_) => api ?? ProductApi(buildDio()),
      child: BlocProvider<CartCubit>(
        create: (_) => CartCubit(),
        child: const V2ProductListPage(),
      ),
    );
  }
}
