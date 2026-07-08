/// 扫码结果的强类型收口。原生把三种情形分别用"回字符串 / 回 null / 抛
/// PERMISSION_DENIED"表达，桥接层统一收成 sealed 类，UI 用 switch 穷尽处理
/// （延续 L1/L2/L3 的"裸值 → 强类型"收口思路）。
///
/// 为什么用 sealed（对标 Swift 的 enum with associated values）：
/// UI 侧 switch 时若漏了某个子类型，编译期就报错——比一堆 if/bool 标志安全得多。
sealed class ScanOutcome {
  const ScanOutcome();
}

/// 扫到码。
class ScanSuccess extends ScanOutcome {
  const ScanSuccess(this.code);

  final String code;
}

/// 用户主动取消（原生返回 null）。
class ScanCancelled extends ScanOutcome {
  const ScanCancelled();
}

/// 相机权限被拒（原生返回 PERMISSION_DENIED 错误）。
class ScanPermissionDenied extends ScanOutcome {
  const ScanPermissionDenied();
}
