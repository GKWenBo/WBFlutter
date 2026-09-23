// Dart String 常见使用示例
void main(List<String> args) {
  // 1. 创建字符串（单引号、双引号、三引号）
  String s1 = 'Hello';
  String s2 = "World";
  String s3 = '''
多行字符串
可以换行
''';
  print(s1);
  print(s2);
  print(s3);

  // 2. 字符串拼接
  String name = 'Dart';
  print(s1 + ' ' + s2); // 使用 +
  print('Hello $name'); // 字符串插值
  print('1 + 2 = ${1 + 2}'); // 表达式插值
  print(
    'ab'
    'cd'
    'ef',
  ); // 相邻字符串自动拼接 => abcdef

  // 3. 字符串长度
  print('Hello'.length); // 5

  // 4. 大小写转换
  print('Hello'.toUpperCase()); // HELLO
  print('Hello'.toLowerCase()); // hello

  // 5. 去除空格
  print('  hi  '.trim()); // 'hi'
  print('  hi  '.trimLeft()); // 'hi  '
  print('  hi  '.trimRight()); // '  hi'

  // 6. 判断是否包含 / 开头 / 结尾
  print('hello world'.contains('world')); // true
  print('hello world'.startsWith('hello')); // true
  print('hello world'.endsWith('world')); // true

  // 7. 查找位置
  print('hello'.indexOf('l')); // 2
  print('hello'.lastIndexOf('l')); // 3

  // 8. 替换
  print('a-b-c'.replaceAll('-', '_')); // a_b_c
  print('a-b-c'.replaceFirst('-', '_')); // a_b-c

  // 9. 截取子串
  print('Hello World'.substring(0, 5)); // Hello
  print('Hello World'.substring(6)); // World

  // 10. 分割与合并
  List<String> parts = 'a,b,c'.split(',');
  print(parts); // [a, b, c]
  print(parts.join('-')); // a-b-c

  // 11. 判断空字符串
  print(''.isEmpty); // true
  print('x'.isNotEmpty); // true

  // 12. 字符串与数字互转
  int n = int.parse('123');
  double d = double.parse('3.14');
  print(n + 1); // 124
  print(d); // 3.14
  print(100.toString()); // '100'

  // 13. 重复字符串
  print('ab' * 3); // ababab

  // 14. 通过索引获取字符（按代码单元）
  print('Hello'[0]); // H

  // 15. 遍历字符
  for (var rune in 'abc'.runes) {
    print(String.fromCharCode(rune));
  }

  // 16. 转义字符与原始字符串
  print('换行\n制表\t结束');
  print(r'原始字符串不转义 \n \t'); // r 前缀表示 raw string

  // 17. padLeft / padRight 补齐
  print('5'.padLeft(3, '0')); // 005
  print('5'.padRight(3, '*')); // 5**
}
