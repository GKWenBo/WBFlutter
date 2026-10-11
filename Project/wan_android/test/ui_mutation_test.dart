import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wan_android/features/cart/data/cart_dependencies.dart';
import 'package:wan_android/features/cart/data/cart_storage.dart';
import 'package:wan_android/features/cart/models.dart';
import 'package:wan_android/features/cart/ui.dart';
import 'package:wan_android/features/products/models.dart';
import 'package:wan_android/features/products/presentation/providers/products_providers.dart';
import 'package:wan_android/features/products/ui.dart';

const product = Product(
  id: 1,
  title: '测试商品',
  description: '',
  category: '',
  price: 10,
  discountPercentage: 0,
  rating: 4,
  stock: 10,
  thumbnail: 'http://x/1.png',
  images: [],
  tags: null,
);

class UiCartStorage extends CartStorage {
  Completer<void>? gate;
  bool fail = false;
  List<CartItem> items = [];
  @override
  Future<List<CartItem>> load() async => items;
  @override
  Future<void> save(List<CartItem> value) async {
    await gate?.future;
    if (fail) throw StateError('写入失败');
    items = List.of(value);
  }
}

void main() {
  Future<void> pumpDetail(WidgetTester tester, UiCartStorage storage) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartStorageProvider.overrideWithValue(storage),
          productProvider(1).overrideWith((ref) async => product),
        ],
        child: const MaterialApp(home: ProductDetailPage(id: 1)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('加购等待保存，提交中禁用，成功后才显示提示', (tester) async {
    final storage = UiCartStorage()..gate = Completer<void>();
    await pumpDetail(tester, storage);
    await tester.tap(find.text('加入购物车'));
    await tester.pump();
    expect(find.textContaining('已加入购物车'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '加入购物车'))
          .onPressed,
      isNull,
    );
    storage.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('已加入购物车'), findsOneWidget);
    expect(storage.items, hasLength(1));
  });
  testWidgets('保存失败显示错误，不显示加购成功', (tester) async {
    final storage = UiCartStorage()..fail = true;
    await pumpDetail(tester, storage);
    await tester.tap(find.text('加入购物车'));
    await tester.pumpAndSettle();
    expect(find.textContaining('操作失败'), findsOneWidget);
    expect(find.textContaining('已加入购物车'), findsNothing);
    expect(storage.items, isEmpty);
  });
  testWidgets('滑动删除保存失败，原行仍可操作', (tester) async {
    final storage = UiCartStorage()
      ..items = [
        const CartItem(
          productId: 1,
          title: '测试商品',
          thumbnail: 'http://x/1.png',
          unitPrice: 10,
          quantity: 1,
        ),
      ]
      ..fail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cartStorageProvider.overrideWithValue(storage)],
        child: const MaterialApp(home: CartPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const ValueKey(1)), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(1)), findsOneWidget);
    expect(find.textContaining('操作失败'), findsOneWidget);
    storage.fail = false;
    await tester.drag(find.byKey(const ValueKey(1)), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(1)), findsNothing);
    expect(storage.items, isEmpty);
  });
}
