import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v4_riverpod/state/cart_notifier.dart';

const _p1 = Product(id: 1, title: 'A', description: 'a', price: 9.99,
    thumbnail: 'x', rating: 4.5);
const _p2 = Product(id: 2, title: 'B', description: 'b', price: 5.01,
    thumbnail: 'x', rating: 4.0);

void main() {
  group('CartNotifier', () {
    late ProviderContainer container;

    setUp(() {
      // ProviderContainer = 无 UI 的 ProviderScope：纯 Dart 测状态层
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    CartNotifier notifier() => container.read(cartProvider.notifier);
    CartState state() => container.read(cartProvider);

    test('add：新商品入车；重复加购只涨数量不加行', () {
      notifier()
        ..add(_p1)
        ..add(_p1)
        ..add(_p2);
      expect(state().items.length, 2);
      expect(state().items.first.quantity, 2);
    });

    test('changeQty：增减数量，减到 0 自动移除', () {
      notifier()
        ..add(_p1)
        ..changeQty(1, 1);
      expect(state().items.first.quantity, 2);
      notifier().changeQty(1, -2);
      expect(state().isEmpty, isTrue);
    });

    test('remove / clear', () {
      notifier()
        ..add(_p1)
        ..add(_p2)
        ..remove(1);
      expect(state().items.single.product.id, 2);
      notifier().clear();
      expect(state().isEmpty, isTrue);
    });

    test('派生值 totalCount / totalPrice 现算', () {
      notifier()
        ..add(_p1)
        ..changeQty(1, 1) // 9.99 × 2
        ..add(_p2); // + 5.01
      expect(state().totalCount, 3);
      expect(state().totalPrice, closeTo(24.99, 0.001));
    });

    test('不可变：内容相同的两个 CartState 值相等（Equatable）', () {
      final other = ProviderContainer();
      addTearDown(other.dispose);
      notifier().add(_p1);
      other.read(cartProvider.notifier).add(_p1);
      expect(state(), other.read(cartProvider));
    });
  });
}
