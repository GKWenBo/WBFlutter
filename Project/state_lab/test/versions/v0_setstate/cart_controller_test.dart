import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v0_setstate/state/cart_controller.dart';

const _p1 = Product(id: 1, title: 'A', description: 'a', price: 9.99,
    thumbnail: 'x', rating: 4.5);
const _p2 = Product(id: 2, title: 'B', description: 'b', price: 5.01,
    thumbnail: 'x', rating: 4.0);

void main() {
  group('CartController', () {
    test('add：新商品入车；重复加购只涨数量不加行', () {
      final cart = CartController();
      cart.add(_p1);
      cart.add(_p1);
      cart.add(_p2);
      expect(cart.items.length, 2);
      expect(cart.items.first.quantity, 2);
    });

    test('changeQty：增减数量，减到 0 自动移除', () {
      final cart = CartController();
      cart.add(_p1);
      cart.changeQty(1, 1);
      expect(cart.items.first.quantity, 2);
      cart.changeQty(1, -2);
      expect(cart.isEmpty, isTrue);
    });

    test('remove / clear', () {
      final cart = CartController();
      cart.add(_p1);
      cart.add(_p2);
      cart.remove(1);
      expect(cart.items.single.product.id, 2);
      cart.clear();
      expect(cart.isEmpty, isTrue);
    });

    test('派生值 totalCount / totalPrice 现算', () {
      final cart = CartController();
      cart.add(_p1);
      cart.changeQty(1, 1); // 9.99 × 2
      cart.add(_p2); // + 5.01
      expect(cart.totalCount, 3);
      expect(cart.totalPrice, closeTo(24.99, 0.001));
    });

    test('每次变更恰好通知一次监听者（改和通知锁进同一扇门）', () {
      final cart = CartController();
      var fired = 0;
      cart.addListener(() => fired++);
      cart.add(_p1); // 1
      cart.changeQty(1, 1); // 2
      cart.remove(1); // 3
      cart.clear(); // 4
      expect(fired, 4);
    });

    test('items 是只读视图：外部改不动，想改必须走方法', () {
      final cart = CartController();
      cart.add(_p1);
      expect(() => cart.items.clear(), throwsUnsupportedError);
    });
  });
}
