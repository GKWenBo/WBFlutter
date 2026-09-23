import 'package:get/get.dart';

import '../../../shared/models/cart_item.dart';
import '../../../shared/models/product.dart';

/// 场景③④：购物车，**自动挡**（Obx + Rx）。对照 v2 的不可变世界，GetX
/// 回到了可变模型——直接复用 shared 那个**可变** CartItem，包一层 RxList。
/// 谁读（Obx 里访问 items/totalCount）谁自动订阅，零手动通知……有一个
/// 大坑除外：**RxList 只感知增/删/整项替换，感知不到元素内部字段变化**
/// ——改 `items[i].quantity` 必须手动 `items.refresh()`，否则界面纹丝不动。
/// 这是 GetX 面试与生产事故的头号高发区（对照：v2 的不可变状态从类型上
/// 杜绝了"偷偷改"，这坑根本不存在）。
class CartGetxController extends GetxController {
  final RxList<CartItem> items = <CartItem>[].obs;

  bool get isEmpty => items.isEmpty;
  int get totalCount => items.fold(0, (sum, it) => sum + it.quantity);
  double get totalPrice => items.fold(0.0, (sum, it) => sum + it.lineTotal);

  void add(Product product) {
    final i = items.indexWhere((it) => it.product.id == product.id);
    if (i >= 0) {
      items[i].quantity += 1;
      items.refresh(); // 改的是元素内部字段：RxList 不知道，手动喊一嗓子
    } else {
      items.add(CartItem(product: product)); // add 本身就是 RxList 的变更，自动通知
    }
  }

  void changeQty(int productId, int delta) {
    final i = items.indexWhere((it) => it.product.id == productId);
    if (i < 0) return;
    items[i].quantity += delta;
    if (items[i].quantity <= 0) {
      items.removeAt(i); // removeAt 自动通知
    } else {
      items.refresh(); // 同 add 的重复加购分支
    }
  }

  void remove(int productId) =>
      items.removeWhere((it) => it.product.id == productId);

  void clear() => items.clear();
}
