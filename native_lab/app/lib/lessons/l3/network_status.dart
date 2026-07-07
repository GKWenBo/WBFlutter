/// 网络状态强类型枚举。原生推来的是裸字符串，进业务层前先收口成枚举，
/// 别让 'wifi'/'none' 这种魔法字符串在 UI 代码里到处比对（同 L1/L2 的收口思路）。
enum NetworkStatus {
  wifi,
  cellular,
  none,
  unknown;

  /// 原生 → Dart 的收口。未知值一律落 unknown（桥接层要宽容）。
  factory NetworkStatus.fromRaw(String? raw) => switch (raw) {
    'wifi' => NetworkStatus.wifi,
    'cellular' => NetworkStatus.cellular,
    'none' => NetworkStatus.none,
    _ => NetworkStatus.unknown,
  };

  /// UI 展示文案。
  String get label => switch (this) {
    NetworkStatus.wifi => 'Wi-Fi 已连接',
    NetworkStatus.cellular => '蜂窝网络',
    NetworkStatus.none => '无网络连接',
    NetworkStatus.unknown => '未知状态',
  };
}

/// 网络信息 = 状态 + 信号强度。L3 课后练习：原生从"推裸字符串"升级成
/// "推 Map{'type','level'}"，复用 L2 的 Map 编解码——流里的每个事件也能是
/// Map/List，codec 规则和 L2 的方法参数完全一样。
class NetworkInfo {
  const NetworkInfo({required this.status, required this.level});

  final NetworkStatus status;

  /// 信号格数 0–3；无网络时为 0。
  final int level;

  /// 原生 → Dart 的收口。EventChannel 的 Map 事件解码成 `Map<Object?, Object?>`，
  /// 桥接层要宽容：拿不到就落 unknown / 0。level 用 `num?.toInt()` 兜住
  /// int/double 差异（L2 踩过的类型坑：原生可能给 Int 也可能给 Double）。
  factory NetworkInfo.fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return const NetworkInfo(status: NetworkStatus.unknown, level: 0);
    }
    return NetworkInfo(
      status: NetworkStatus.fromRaw(map['type'] as String?),
      level: (map['level'] as num?)?.toInt() ?? 0,
    );
  }

  // 值相等：让测试能直接 expect(info, NetworkInfo(...))，也便于流去重。
  @override
  bool operator ==(Object other) =>
      other is NetworkInfo && other.status == status && other.level == level;

  @override
  int get hashCode => Object.hash(status, level);

  @override
  String toString() => 'NetworkInfo(status: $status, level: $level)';
}
