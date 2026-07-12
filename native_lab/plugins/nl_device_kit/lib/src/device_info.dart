/// 插件自己的设备信息强类型（与 app 内 L1 的 DeviceInfo 各自独立——并行对照）。
/// 教学点：插件对外只吐强类型，别让 Map 漏进消费方的业务代码。
class DeviceInfo {
  const DeviceInfo({
    required this.model,
    required this.systemName,
    required this.systemVersion,
    required this.appVersion,
  });

  factory DeviceInfo.fromMap(Map<String, Object?> map) => DeviceInfo(
        model: map['model'] as String? ?? 'unknown',
        systemName: map['systemName'] as String? ?? 'unknown',
        systemVersion: map['systemVersion'] as String? ?? 'unknown',
        appVersion: map['appVersion'] as String? ?? 'unknown',
      );

  final String model;
  final String systemName;
  final String systemVersion;
  final String appVersion;
}
