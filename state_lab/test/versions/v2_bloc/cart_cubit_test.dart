import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v2_bloc/state/cart_cubit.dart';
import 'package:state_lab/versions/v2_bloc/state/cart_state.dart';

const _p1 = Product(id: 1, title: 'A', description: 'a', price: 9.99,
    thumbnail: 'x', rating: 4.5);
const _p2 = Product(id: 2, title: 'B', description: 'b', price: 5.01,
    thumbnail: 'x', rating: 4.0);

void main() {
  group('CartCubit', () {
    blocTest<CartCubit, CartState>(
      'add：新商品入车；重复加购只涨数量不加行',
      build: CartCubit.new,
      act: (c) => c
        ..add(_p1)
        ..add(_p1)
        ..add(_p2),
      expect: () => [
        isA<CartState>().having((s) => s.items.length, 'len', 1),
        isA<CartState>().having((s) => s.items.first.quantity, 'q', 2),
        isA<CartState>().having((s) => s.items.length, 'len', 2),
      ],
    );

    blocTest<CartCubit, CartState>(
      'changeQty：增减数量，减到 0 自动移除',
      build: CartCubit.new,
      act: (c) => c
        ..add(_p1)
        ..changeQty(1, 1)
        ..changeQty(1, -2),
      expect: () => [
        isA<CartState>().having((s) => s.items.single.quantity, 'q', 1),
        isA<CartState>().having((s) => s.items.single.quantity, 'q', 2),
        isA<CartState>().having((s) => s.isEmpty, 'empty', true),
      ],
    );

    blocTest<CartCubit, CartState>(
      'remove / clear',
      build: CartCubit.new,
      act: (c) => c
        ..add(_p1)
        ..add(_p2)
        ..remove(1)
        ..clear(),
      skip: 2, // 跳过两次 add，只看 remove/clear 结果
      expect: () => [
        isA<CartState>().having((s) => s.items.single.product.id, 'id', 2),
        isA<CartState>().having((s) => s.isEmpty, 'empty', true),
      ],
    );

    test('派生值 totalCount / totalPrice 现算', () {
      final cubit = CartCubit()
        ..add(_p1)
        ..changeQty(1, 1) // 9.99 × 2
        ..add(_p2); // + 5.01
      expect(cubit.state.totalCount, 3);
      expect(cubit.state.totalPrice, closeTo(24.99, 0.001));
    });

    test('不可变：两个内容相同的 CartState 值相等（Equatable）', () {
      final a = CartCubit()..add(_p1);
      final b = CartCubit()..add(_p1);
      expect(a.state, b.state); // 值语义，非引用
    });
  });
}
