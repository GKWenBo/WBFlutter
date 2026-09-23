import 'product.dart';

/// 购物车行项目。
/// 注意 quantity 是**可变**字段——v0 的原始玩法就是"共享一个可变对象，
/// 改完各自想办法通知界面"。后面 Bloc 课会看到不可变状态的对立面写法。
class CartItem {
  CartItem({required this.product, this.quantity = 1});

  final Product product;
  int quantity;

  /// 行小计（派生值：任何时刻都从数据算出，不落地存储）。
  double get lineTotal => product.price * quantity;
}
