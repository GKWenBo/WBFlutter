// =============================================================================
// XxxTransition 合集 —— 显式动画的"现成组件"
//
// 和隐式 AnimatedXxx 对照：
//   隐式  AnimatedOpacity(opacity: 0.5)      ← 传"值"
//   显式  FadeTransition(opacity: animation) ← 传"Animation 对象"，由 controller 驱动
//
// 常用：FadeTransition / ScaleTransition / RotationTransition / SlideTransition /
//      SizeTransition / PositionedTransition / DecoratedBoxTransition / AlignTransition
//
// 性能：XxxTransition 只在动画值变化时重绘自身（FadeTransition 甚至不触发 build），
//      比"setState 每帧重建"高效得多。
//
// iOS 对应：CABasicAnimation(keyPath: "opacity" / "transform.scale" / "transform.rotation" / "position")
// =============================================================================

import 'package:flutter/material.dart';

import '../../widgets/demo_scaffold.dart';

class TransitionsDemo extends StatefulWidget {
  const TransitionsDemo({super.key});

  @override
  State<TransitionsDemo> createState() => _TransitionsDemoState();
}

class _TransitionsDemoState extends State<TransitionsDemo> with SingleTickerProviderStateMixin {
  // 一个 controller 驱动全部 5 个 Transition，演示"一个时间轴，多个属性"
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  late final Animation<double> _curved = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  // SlideTransition 的偏移单位是"子组件自身尺寸的倍数"，(1, 0) = 向右移动一个自身宽度
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(-0.5, 0),
    end: const Offset(0.5, 0),
  ).animate(_curved);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    Widget box() => Container(width: 56, height: 56, color: color);

    return DemoScaffold(
      title: 'XxxTransition 合集',
      iosAnalogy: '≈ CABasicAnimation(keyPath: opacity / transform.scale / position…)',
      tips: const [
        '隐式传"值"，显式 Transition 传 Animation 对象',
        'SlideTransition 偏移单位是"自身尺寸倍数"，不是像素',
        'RotationTransition 的 turns 单位是圈，1.0 = 360°',
      ],
      child: Column(
        children: [
          _item('FadeTransition', FadeTransition(opacity: _curved, child: box())),
          _item(
            'ScaleTransition',
            ScaleTransition(
              scale: Tween<double>(begin: 0.5, end: 1.2).animate(_curved),
              child: box(),
            ),
          ),
          _item('RotationTransition', RotationTransition(turns: _curved, child: box())),
          _item('SlideTransition', SlideTransition(position: _slide, child: box())),
          _item(
            'SizeTransition',
            SizedBox(
              height: 56,
              child: SizeTransition(
                sizeFactor: _curved,
                axis: Axis.horizontal, // 水平方向展开
                alignment: AlignmentDirectional.centerStart, // 从左边开始展开（3.41 起取代 axisAlignment）
                child: Container(width: 200, height: 56, color: color),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton(onPressed: () => _controller.repeat(reverse: true), child: const Text('播放')),
              const SizedBox(width: 12),
              OutlinedButton(onPressed: _controller.stop, child: const Text('暂停')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _item(String title, Widget demo) {
    return SizedBox(
      height: 96,
      child: Row(
        children: [
          SizedBox(width: 150, child: Text(title)),
          Expanded(child: Center(child: demo)),
        ],
      ),
    );
  }
}
