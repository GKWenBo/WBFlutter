import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/api/product_api.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v0_setstate/v0_shop_root.dart';

const _fakeProducts = [
  Product(id: 1, title: '测试商品A', description: '描述A', price: 9.99,
      thumbnail: 'x', rating: 4.5, brand: '测试牌'),
  Product(id: 2, title: '测试商品B', description: '描述B', price: 5.01,
      thumbnail: 'x', rating: 4.0),
];

/// 手写 Fake（≈ iOS 单测里手写一个假 Service）：不发网络，立即返回固定数据。
class FakeProductApi implements ProductApi {
  @override
  Future<ProductPage> fetchProducts({
    required int skip,
    int limit = ProductApi.pageSize,
  }) async {
    return ProductPage(
      products: skip == 0 ? _fakeProducts : const [],
      total: _fakeProducts.length,
      skip: skip,
      limit: limit,
    );
  }

  @override
  Future<List<Product>> searchProducts(String query) async =>
      _fakeProducts.where((p) => p.title.contains(query)).toList();
}

void main() {
  testWidgets('v0 主流程：列表加载 → 加购 → 角标 → 购物车增减/合计 → 清空', (tester) async {
    await tester.pumpWidget(MaterialApp(home: V0ShopRoot(api: FakeProductApi())));
    await tester.pump(); // initState 触发首屏加载
    await tester.pump(); // Future 完成后的 setState 落地

    expect(find.text('测试商品A'), findsOneWidget);
    expect(find.text('测试商品B'), findsOneWidget);

    // 加购第一件 → AppBar 角标显示 1
    await tester.tap(find.byIcon(Icons.add_shopping_cart).first);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // 进购物车
    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('测试商品A'), findsOneWidget);

    // 数量 +1 → 合计更新（9.99 × 2）
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    expect(find.text('共 2 件'), findsOneWidget);
    expect(find.textContaining('19.98'), findsOneWidget);

    // 清空 → 空态
    await tester.tap(find.text('清空'));
    await tester.pump();
    expect(find.text('购物车是空的'), findsOneWidget);
  });

  testWidgets('学员发现的 bug：详情页 → 购物车清空 → 返回详情页，角标必须清零', (tester) async {
    await tester.pumpWidget(MaterialApp(home: V0ShopRoot(api: FakeProductApi())));
    await tester.pump();
    await tester.pump();

    // 进详情页
    await tester.tap(find.text('测试商品A'));
    await tester.pumpAndSettle();

    // 详情页底部加购 → 本页角标显示 1
    await tester.tap(find.text('加入购物车'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // 从详情页进购物车 → 清空
    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空'));
    await tester.pump();
    expect(find.text('购物车是空的'), findsOneWidget);

    // 返回详情页：角标必须消失（pop 回来要能感知到购物车已变）
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);
  });
}
