// Dart List（列表）常见使用示例
void main(List<String> args) {
  // 1. 创建列表
  List<int> nums = [1, 2, 3]; // 字面量创建
  var names = <String>['张三', '李四']; // 指定泛型
  List<int> empty = []; // 空列表
  List<int> filled = List.filled(3, 0); // 固定长度，填充默认值 [0, 0, 0]
  List<int> gen = List.generate(3, (i) => i * i); // 通过函数生成 [0, 1, 4]
  print(nums);
  print(names);
  print(empty);
  print(filled);
  print(gen);

  // 2. 访问元素
  print(nums[0]); // 1
  print(nums.first); // 第一个 1
  print(nums.last); // 最后一个 3
  print(nums.length); // 长度 3

  // 3. 修改元素
  nums[0] = 100;
  print(nums); // [100, 2, 3]

  // 4. 添加元素
  nums.add(4); // 末尾添加单个 [100, 2, 3, 4]
  nums.addAll([5, 6]); // 添加多个 [100, 2, 3, 4, 5, 6]
  nums.insert(0, 0); // 指定位置插入 [0, 100, 2, 3, 4, 5, 6]
  print(nums);

  // 5. 删除元素
  nums.remove(100); // 删除指定值
  nums.removeAt(0); // 删除指定索引
  nums.removeLast(); // 删除最后一个
  nums.removeWhere((e) => e > 4); // 按条件删除
  print(nums); // [2, 3, 4]

  // 6. 查找
  print(nums.contains(3)); // true
  print(nums.indexOf(3)); // 1
  print(nums.isEmpty); // false
  print(nums.isNotEmpty); // true

  // 7. 遍历列表
  for (int n in nums) {
    print('for-in: $n');
  }
  nums.forEach((n) => print('forEach: $n'));
  for (int i = 0; i < nums.length; i++) {
    print('索引 $i = ${nums[i]}');
  }

  // 8. map：转换每个元素
  List<int> doubled = nums.map((e) => e * 2).toList();
  print(doubled); // [4, 6, 8]

  // 9. where：过滤
  List<int> evens = [1, 2, 3, 4, 5, 6].where((e) => e % 2 == 0).toList();
  print(evens); // [2, 4, 6]

  // 10. reduce / fold：聚合
  int sum = [1, 2, 3, 4].reduce((a, b) => a + b);
  print(sum); // 10
  int sumWithInit = [1, 2, 3, 4].fold(100, (a, b) => a + b);
  print(sumWithInit); // 110

  // 11. 排序
  List<int> sortList = [3, 1, 2];
  sortList.sort(); // 升序 [1, 2, 3]
  print(sortList);
  sortList.sort((a, b) => b - a); // 降序 [3, 2, 1]
  print(sortList);

  // 12. 反转
  print([1, 2, 3].reversed.toList()); // [3, 2, 1]

  // 13. 截取子列表
  print([1, 2, 3, 4, 5].sublist(1, 3)); // [2, 3]
  print([1, 2, 3, 4, 5].take(2).toList()); // 前两个 [1, 2]
  print([1, 2, 3, 4, 5].skip(2).toList()); // 跳过前两个 [3, 4, 5]

  // 14. 拼接与合并
  print([1, 2] + [3, 4]); // [1, 2, 3, 4]

  // 15. 展开运算符（spread）
  List<int> a = [1, 2];
  List<int> b = [0, ...a, 3]; // [0, 1, 2, 3]
  List<int>? maybeNull;
  List<int> c = [0, ...?maybeNull, 1]; // ...? 处理可能为 null 的情况
  print(b);
  print(c); // [0, 1]

  // 16. 集合中的条件元素（collection if / for）
  bool showExtra = true;
  List<int> d = [
    1,
    2,
    if (showExtra) 3, // 条件添加
    for (int i = 4; i <= 6; i++) i, // 循环添加
  ];
  print(d); // [1, 2, 3, 4, 5, 6]

  // 17. join：转为字符串
  print([1, 2, 3].join('-')); // 1-2-3

  // 18. 其他常用判断
  print([2, 4, 6].every((e) => e % 2 == 0)); // 全部满足 true
  print([1, 2, 3].any((e) => e > 2)); // 任一满足 true

  // 19. 去重（借助 Set）
  print([1, 1, 2, 3, 3].toSet().toList()); // [1, 2, 3]

  // 20. 清空
  List<int> e = [1, 2, 3];
  e.clear();
  print(e); // []
}
