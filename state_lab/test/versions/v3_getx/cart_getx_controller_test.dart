import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v3_getx/state/cart_getx_controller.dart';

const _p1 = Product(id: 1, title: 'A', description: 'a', price: 9.99,
    thumbnail: 'x', rating: 4.5);
const _p2 = Product(id: 2, title: 'B', description: 'b', price: 5.01,
    thumbnail: 'x', rating: 4.0);

void main() {
  group('CartGetxController', () {
    test('add：新商品入车；重复加购只涨数量不加行', () {
      final cart = CartGetxController();
      cart.add(_p1);
      cart.add(_p1);
      cart.add(_p2);
      expect(cart.items.length, 2);
      expect(cart.items.first.quantity, 2);
    });

    test('changeQty：增减数量，减到 0 自动移除', () {
      final cart = CartGetxController();
      cart.add(_p1);
      cart.changeQty(1, 1);
      expect(cart.items.first.quantity, 2);
      cart.changeQty(1, -2);
      expect(cart.isEmpty, isTrue);
    });

    test('remove / clear', () {
      final cart = CartGetxController();
      cart.add(_p1);
      cart.add(_p2);
      cart.remove(1);
      expect(cart.items.single.product.id, 2);
      cart.clear();
      expect(cart.isEmpty, isTrue);
    });

    test('派生值 totalCount / totalPrice 现算', () {
      final cart = CartGetxController();
      cart.add(_p1);
      cart.changeQty(1, 1); // 9.99 × 2
      cart.add(_p2); // + 5.01
      expect(cart.totalCount, 3);
      expect(cart.totalPrice, closeTo(24.99, 0.001));
    });

    test('RxList 语义：增删自动发流；改元素内部字段必须 refresh 才发', () async {
      final cart = CartGetxController();
      var fired = 0;
      final sub = cart.items.listen((_) => fired++);

      cart.add(_p1); // RxList.add → 自动通知
      await Future<void>.delayed(Duration.zero);
      expect(fired, 1);

      // 教学点复现：绕过方法直接改元素内部字段——RxList 毫无感知
      cart.items[0].quantity = 99;
      await Future<void>.delayed(Duration.zero);
      expect(fired, 1, reason: '改内部字段不发流：界面会纹丝不动');

      cart.add(_p1); // 走方法：内部 refresh() 手动补了通知
      await Future<void>.delayed(Duration.zero);
      expect(fired, 2);

      await sub.cancel();
    });
  });
}
