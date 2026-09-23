import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'scan_outcome.dart';

/// L4 扫码桥（Dart 侧）。第四条 channel。
///
/// 页面级混合：原生不是回一个数据，而是"接管整块屏幕"present 一个原生扫码页，
/// 等用户扫完/取消后再回传结果——但 Dart 侧用法仍是一次 invokeMethod。
///
/// 关键差异（对比 L1/L2）：原生那次 result 是"延迟"的（用户操作后才回来），
/// 不像读设备信息那样 handler 里立刻就回。但从 Dart 看仍是等一个 Future，
/// 所以测试用回 MethodChannel 的 setMockMethodCallHandler（不是 L3 的流那套）。
class ScanBridge {
  ScanBridge._();

  @visibleForTesting
  static const MethodChannel channel = MethodChannel(
    'com.wenbo.native_lab/scanner',
  );

  /// 打开原生扫码页，返回强类型结果。
  /// 协议约定（三端一致）：扫到码 → 回 code 字符串；用户取消 → 回 null；
  /// 相机权限被拒 → 抛 PlatformException(code: 'PERMISSION_DENIED')。
  ///
  /// [hint] 是打开原生页时携带的提示语，原生把它当扫码页标题（L4 课后练习）——
  /// "打开原生页"一样能带入参下去，Map 入参的编解码规则和 L2 完全一样。
  static Future<ScanOutcome> scan({String? hint}) async {
    try {
      final code = await channel.invokeMethod<String>('scan', {'hint': hint});
      return code == null ? const ScanCancelled() : ScanSuccess(code);
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        return const ScanPermissionDenied();
      }
      rethrow; // 其它错误（如 ALREADY_SCANNING）不吞，交给上层
    }
  }
}
