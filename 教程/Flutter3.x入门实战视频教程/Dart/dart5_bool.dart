// Dart bool 布尔类型 常见使用示例
void main(List<String> args) {
  // 1. 声明布尔变量，只有 true / false 两个值
  bool isActive = true;
  bool isDone = false;
  print(isActive); // true
  print(isDone); // false

  // 2. 比较运算符返回 bool
  print(3 > 2); // true
  print(3 < 2); // false
  print(3 == 3); // true   相等
  print(3 != 4); // true   不相等
  print(3 >= 3); // true
  print(3 <= 2); // false

  // 3. 逻辑运算符
  print(true && true); // true   与：两边都为 true 才为 true
  print(true && false); // false
  print(true || false); // true   或：有一个为 true 即为 true
  print(false || false); // false
  print(!true); // false  非：取反

  // 4. 短路求值
  // && 左边为 false 时，右边不再执行
  // || 左边为 true 时，右边不再执行
  print(check('A', true) || check('B', true)); // 只打印 A，再输出 true
  print(check('C', false) && check('D', true)); // 只打印 C，再输出 false

  // 5. 在条件语句中使用
  int age = 20;
  if (age >= 18) {
    print('成年人');
  } else {
    print('未成年人');
  }

  // 6. 三元表达式
  String text = isActive ? '已激活' : '未激活';
  print(text); // 已激活

  // 7. Dart 中条件必须是 bool，不能用非 0 数字代替
  // if (1) {}        // 错误：if 的条件必须是 bool
  int count = 0;
  if (count == 0) {
    print('没有数据'); // 正确写法：显式比较
  }

  // 8. 字符串 / 集合相关的 bool 属性
  print(''.isEmpty); // true
  print('hi'.isNotEmpty); // true
  print([1, 2, 3].contains(2)); // true
  print([1, 2, 3].isEmpty); // false

  // 9. 字符串转 bool（没有 bool.parse，可自行比较）
  String input = 'true';
  bool flag = input == 'true';
  print(flag); // true

  // 10. bool 转字符串
  print(true.toString()); // 'true'

  // 11. 可空布尔 bool? 与默认值
  bool? maybe; // 未赋值时为 null
  print(maybe); // null
  print(maybe ?? false); // false  使用 ?? 提供默认值
}

// 辅助函数：打印标记并返回指定布尔值，用于观察短路求值是否执行
bool check(String tag, bool value) {
  print(tag);
  return value;
}
