import 'dart:convert';

import '../domain/product.dart';

/// M2 临时本地样例数据。
///
/// 这是一段"刻意长得像 DummyJSON `/products` 接口返回"的 JSON 字符串。
/// 解析链路：jsonDecode(字符串) → `List<dynamic>` → 每个 Map 走 Product.fromJson。
/// M3 接 dio 后，只是把"读这段字符串"换成"网络请求拿到 response.data"，解析这步完全复用。
const _rawProductsJson = '''
[
  {"id":1,"title":"iPhone 15 Pro 钛金属原色 256GB","description":"A17 Pro 芯片，钛金属边框。","category":"smartphones","price":999,"discountPercentage":8.5,"rating":4.9,"stock":12,"brand":"Apple","thumbnail":"https://picsum.photos/seed/p1/300","images":["https://picsum.photos/seed/p1/600"],"tags":["新品","旗舰","5G"]},
  {"id":2,"title":"无线降噪耳机 旗舰款","description":"主动降噪，30 小时续航。","category":"audio","price":249.5,"discountPercentage":12,"rating":4.6,"stock":40,"brand":"Sony","thumbnail":"https://picsum.photos/seed/p2/300","images":["https://picsum.photos/seed/p2/600"],"tags":["降噪","蓝牙"]},
  {"id":3,"title":"14 英寸轻薄笔记本电脑 M 系列芯片","description":"全天候续航，轻至 1.2kg。","category":"laptops","price":1599,"discountPercentage":5,"rating":4.8,"stock":8,"brand":"Apple","thumbnail":"https://picsum.photos/seed/p3/300","images":["https://picsum.photos/seed/p3/600"],"tags":["轻薄","长续航","办公"]},
  {"id":4,"title":"智能运动手表","description":"心率/血氧/GPS 全能。","category":"wearables","price":199,"discountPercentage":15,"rating":4.3,"stock":60,"thumbnail":"https://picsum.photos/seed/p4/300","images":["https://picsum.photos/seed/p4/600"],"tags":["运动","健康"]},
  {"id":5,"title":"4K 微单相机套机（含 18-55mm 镜头）","description":"对焦快，画质好。","category":"cameras","price":899,"discountPercentage":10,"rating":4.7,"stock":15,"brand":"Fujifilm","thumbnail":"https://picsum.photos/seed/p5/300","images":["https://picsum.photos/seed/p5/600"],"tags":[]},
  {"id":6,"title":"机械键盘 87 键","description":"热插拔轴体，RGB 背光。","category":"accessories","price":79.9,"discountPercentage":20,"rating":4.5,"stock":120,"thumbnail":"https://picsum.photos/seed/p6/300","images":["https://picsum.photos/seed/p6/600"]}
]
''';

/// 把样例 JSON 解析成强类型的 `List<Product>`。
List<Product> sampleProducts() {
  // jsonDecode 返回 dynamic，这里我们知道顶层是数组 → as List<dynamic>。
  final raw = jsonDecode(_rawProductsJson) as List<dynamic>;
  // 每个元素是一个 Map，交给 Product.fromJson 转成对象。
  return raw
      .map((e) => Product.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}
