import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/shared/widgets/async_state_view.dart';
import 'package:state_lab/shared/widgets/cart_icon_button.dart';
import 'package:state_lab/shared/widgets/product_card.dart';

const _product = Product(
  id: 1, title: '测试商品', description: 'd', price: 9.99,
  thumbnail: 'https://example.com/x.png', rating: 4.5, brand: '测试牌',
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('ProductCard 展示商品并回调加购', (tester) async {
    var addCount = 0;
    var tapCount = 0;
    await tester.pumpWidget(_wrap(ProductCard(
      product: _product,
      onTap: () => tapCount++,
      onAddToCart: () => addCount++,
    )));

    expect(find.text('测试商品'), findsOneWidget);
    expect(find.textContaining('9.99'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_shopping_cart));
    expect(addCount, 1);
    await tester.tap(find.text('测试商品'));
    expect(tapCount, 1);
  });

  testWidgets('AsyncStateView 三态分支：loading > error > data', (tester) async {
    await tester.pumpWidget(_wrap(AsyncStateView(
      loading: true, error: null, onRetry: () {},
      builder: (_) => const Text('data'),
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    var retried = 0;
    await tester.pumpWidget(_wrap(AsyncStateView(
      loading: false, error: '网络挂了', onRetry: () => retried++,
      builder: (_) => const Text('data'),
    )));
    expect(find.text('网络挂了'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(retried, 1);

    await tester.pumpWidget(_wrap(AsyncStateView(
      loading: false, error: null, onRetry: () {},
      builder: (_) => const Text('data'),
    )));
    expect(find.text('data'), findsOneWidget);
  });

  testWidgets('CartIconButton：count>0 显示角标，==0 隐藏', (tester) async {
    await tester.pumpWidget(_wrap(CartIconButton(count: 3, onPressed: () {})));
    expect(find.text('3'), findsOneWidget);

    await tester.pumpWidget(_wrap(CartIconButton(count: 0, onPressed: () {})));
    expect(find.text('0'), findsNothing);
  });
}
