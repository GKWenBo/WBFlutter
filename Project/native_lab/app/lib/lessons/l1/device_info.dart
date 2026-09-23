/// 设备信息模型（企业场景：风控/日志上报的标配字段）。
/// 教学点：channel 传回来的是 Map，进业务层前先收口成强类型，
/// 别让 `Map<String, dynamic>` 在业务代码里到处漂。
class DeviceInfo {
  const DeviceInfo({
    required this.model,
    required this.systemName,
    required this.systemVersion,
    required this.appVersion,
  });

  /// 解析原生传来的 Map。字段缺失给兜底值而不是崩——
  /// 双端实现难免有出入，桥接层要宽容（对比：业务真身数据不吞错）。
  factory DeviceInfo.fromMap(Map<String, Object?> map) {
    return DeviceInfo(
      model: map['model'] as String? ?? 'unknown',
      systemName: map['systemName'] as String? ?? 'unknown',
      systemVersion: map['systemVersion'] as String? ?? 'unknown',
      appVersion: map['appVersion'] as String? ?? 'unknown',
    );
  }

  final String model;
  final String systemName;
  final String systemVersion;
  final String appVersion;
}
