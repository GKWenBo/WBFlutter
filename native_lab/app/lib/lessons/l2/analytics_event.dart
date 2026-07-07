/// 埋点事件模型。企业里一个事件 = 事件名 + 一坨属性；
/// 属性值类型五花八门（字符串/数字/布尔/数组/嵌套对象），
/// 正好把 StandardMessageCodec 的类型系统全踩一遍。
class AnalyticsEvent {
  const AnalyticsEvent({required this.name, this.properties = const {}});

  final String name;

  /// 属性值只能是 codec 支持的类型（见课时文档的类型映射表），
  /// 塞进去不支持的类型（比如自定义类实例）编码期就会抛。
  /// 故意用 Object? 而不是 dynamic：逼调用方对"能放什么"心里有数。
  final Map<String, Object?> properties;

  /// 过桥前拍平成 Map——channel 只认 codec 支持的裸结构，不认自定义类。
  /// iOS 类比：像把 model 转成要塞进 NSDictionary 的原始字段。
  Map<String, Object?> toMap() => {'name': name, 'properties': properties};

  /// 原生传回来的每个元素是 `Map<Object?, Object?>`，先 cast 收窄再收口成模型。
  factory AnalyticsEvent.fromMap(Map<String, Object?> map) => AnalyticsEvent(
    name: map['name'] as String? ?? '',
    properties:
        (map['properties'] as Map?)?.cast<String, Object?>() ?? const {},
  );
}
