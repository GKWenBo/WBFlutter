// Dart 数字类型 常见使用示例
void main(List<String> args) {
  // 1. 整数 int 与 浮点数 double
  int i = 10;
  double d = 3.14;
  print(i); // 10
  print(d); // 3.14

  // num 是 int 和 double 的父类型，可同时存储两者
  num n1 = 100; // 整数
  num n2 = 2.5; // 浮点数
  print(n1); // 100
  print(n2); // 2.5

  // 2. 不同进制的整数字面量
  int hex = 0xFF; // 十六进制 => 255
  print(hex); // 255

  // 3. 基本算术运算
  print(7 + 2); // 9
  print(7 - 2); // 5
  print(7 * 2); // 14
  print(7 / 2); // 3.5  （除法结果为 double）
  print(7 ~/ 2); // 3    （整除，取整数商）
  print(7 % 2); // 1    （取余）

  // 4. 自增自减
  int count = 1;
  count++;
  print(count); // 2
  count--;
  print(count); // 1

  // 5. 常用属性判断
  print(10.isEven); // true   是否为偶数
  print(7.isOdd); // true   是否为奇数
  print((-5).isNegative); // true   是否为负数
  print(0.isFinite); // true   是否为有限数

  // 6. 取整相关方法
  print(3.7.round()); // 4   四舍五入
  print(3.7.floor()); // 3   向下取整
  print(3.2.ceil()); // 4   向上取整
  print(3.7.truncate()); // 3   截断小数部分

  // 7. 绝对值与符号
  print((-8).abs()); // 8
  print(5.sign); // 1    正数返回 1，负数返回 -1，0 返回 0

  // 8. 取最大值 / 最小值
  print(5.clamp(0, 3)); // 3   把数值限制在 [0, 3] 范围内
  print(3.compareTo(5)); // -1  小于返回负数

  // 9. 保留小数位（返回字符串）
  print(3.14159.toStringAsFixed(2)); // 3.14
  print(123.456.toStringAsPrecision(4)); // 123.5

  // 10. 数字与字符串互转
  int a = int.parse('42'); // 字符串转 int
  double b = double.parse('3.14'); // 字符串转 double
  print(a + 1); // 43
  print(b); // 3.14
  print(255.toRadixString(16)); // 'ff'  转为十六进制字符串

  // tryParse 解析失败返回 null，不会抛异常
  print(int.tryParse('abc')); // null
  print(int.tryParse('100')); // 100

  // 11. int 与 double 互转
  print(10.toDouble()); // 10.0
  print(3.9.toInt()); // 3    丢弃小数部分

  // 12. 特殊值
  print(double.infinity); // Infinity
  print(double.nan); // NaN
  print(double.nan.isNaN); // true   判断是否为 NaN（NaN 不等于任何值，包括自身）
}
