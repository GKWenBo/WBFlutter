void main(List<String> args) {
  var list = ["张三", 20, true];
  print(list);
  print(list[0]);
  print(list.length);

  // 指定类型
  List<String> list1 = ["张三", "李四", "王五"];
  print(list1);

  // 添加数据
  list1.add("赵六");
  print(list1);
}
