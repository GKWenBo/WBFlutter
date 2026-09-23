import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 重建计数徽标（debug 专用教学道具）：所在区块每 rebuild 一次，计数 +1。
/// S5 对比各方案（Selector / buildWhen / Obx）如何收窄重建范围时，肉眼可见。
///
/// 计数存在静态 Map 里而不是 State 里——如果存 State，Widget 自己重建时
/// 计数就归零了，恰好数不到自己（鸡生蛋问题）。
class RebuildBadge extends StatelessWidget {
  const RebuildBadge({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  static final Map<String, int> _counts = {};

  /// 测试间清零，避免用例互相污染。
  @visibleForTesting
  static void reset() => _counts.clear();

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;
    final count = _counts.update(label, (n) => n + 1, ifAbsent: () => 1);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -2,
          top: -2,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$label:$count',
                style: const TextStyle(color: Colors.white, fontSize: 9),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
