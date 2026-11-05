// =============================================================================
// 交错动画（Staggered Animation）—— 一个 controller，多段错开的动画
//
// 核心：Interval(begin, end, curve: ...)
//   把 controller 的 0→1 切出一段：Interval(0.2, 0.6) 表示在总时长 20%~60% 这段里才从 0 走到 1，
//   之前一直是 0，之后一直是 1。给每个元素不同的 Interval → 依次入场。
//
// iOS 对应：CAAnimationGroup + 每个子动画设置不同的 beginTime；
//          或 UIView.animate(withDuration:delay:) 每个 view 递增 delay。
// 优势：一个 controller 统一控制，可整体反向/暂停/拖进度，比多个 delay 好管理。
// =============================================================================

import 'package:flutter/material.dart';

import '../../widgets/demo_scaffold.dart';

class StaggeredDemo extends StatefulWidget {
  const StaggeredDemo({super.key});

  @override
  State<StaggeredDemo> createState() => _StaggeredDemoState();
}

class _StaggeredDemoState extends State<StaggeredDemo> with SingleTickerProviderStateMixin {
  static const _itemCount = 6;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  // 每一项的动画区间，创建一次复用
  late final List<Animation<double>> _itemAnimations = List.generate(_itemCount, _intervalFor);

  @override
  void initState() {
    super.initState();
    _controller.forward(); // 进页面就播放
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 第 [index] 项的动画区间：每项错开 0.1，持续 0.5。
  /// index=0 → 0.0~0.5，index=5 → 0.5~1.0
  Animation<double> _intervalFor(int index) {
    final start = index * 0.1;
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, start + 0.5, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DemoScaffold(
      title: '交错动画',
      iosAnalogy: '≈ CAAnimationGroup + 不同 beginTime / UIView.animate(delay:) 递增',
      tips: const [
        'Interval(begin, end) 的取值都在 0~1，是"总时长的比例"',
        '一个 controller 统一控制，反向/重播都只需一行',
        '同一元素可以叠多个 Interval：先淡入、再位移、最后缩放',
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _itemCount; i++)
            _StaggerItem(
              animation: _itemAnimations[i],
              child: Card(
                color: scheme.primaryContainer,
                child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text('列表项 ${i + 1}'),
                  subtitle: Text('Interval(${(i * 0.1).toStringAsFixed(1)}, ${(i * 0.1 + 0.5).toStringAsFixed(1)})'),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton(
                onPressed: () => _controller.forward(from: 0),
                child: const Text('重播'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => _controller.reverse(),
                child: const Text('反向退场'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 单个列表项：淡入 + 从右侧滑入。
class _StaggerItem extends StatelessWidget {
  const _StaggerItem({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }
}
