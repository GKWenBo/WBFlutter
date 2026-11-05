// =============================================================================
// 拖拽 + 弹簧回弹 —— 手势驱动 & 物理动画
//
// 思路：
//   拖动中：GestureDetector.onPanUpdate 直接改位置（跟手，不需要动画）
//   松手后：用 SpringSimulation 从"当前位置 + 松手速度"弹回原点
//          controller.animateWith(simulation) 让 controller 按物理模拟推进，而不是固定 duration
//
// iOS 对应：
//   UIPanGestureRecognizer + UIView.animate(usingSpringWithDamping:initialSpringVelocity:)
//   或 UIViewPropertyAnimator(springTimingParameters:)
//   SwiftUI: DragGesture + .spring()
//
// 关键：把松手速度传给 simulation，才会有"甩出去再弹回来"的真实手感。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../widgets/demo_scaffold.dart';

class DragSpringDemo extends StatefulWidget {
  const DragSpringDemo({super.key});

  @override
  State<DragSpringDemo> createState() => _DragSpringDemoState();
}

class _DragSpringDemoState extends State<DragSpringDemo> with SingleTickerProviderStateMixin {
  // unbounded：物理模拟的值不限于 0~1（这里 controller 的 value 表示"回弹进度"）
  late final AnimationController _controller;

  Offset _offset = Offset.zero; // 卡片当前偏移
  Offset _releaseOffset = Offset.zero; // 松手时的偏移（回弹起点）

  // 弹簧参数：mass 质量、stiffness 刚度（越大越"硬"越快）、damping 阻尼（越小越晃）
  double _stiffness = 180;
  double _damping = 12;

  @override
  void initState() {
    super.initState();
    // ⚠️ 坑：这里不能写成 `late final _controller = AnimationController(...)` 懒加载！
    // 这个页面只有拖动才会用到 controller，若用户从没拖过，第一次访问会发生在 dispose() 里，
    // 此时 element 已失活，创建 Ticker 去查 TickerMode 会报
    // "Looking up a deactivated widget's ancestor is unsafe"。在 initState 里显式创建最稳妥。
    _controller = AnimationController.unbounded(vsync: this)..addListener(_onTick);
  }

  void _onTick() {
    // controller.value：0 = 在松手位置，1 = 回到原点。弹簧会在 1 附近来回晃（>1 就是冲过头）
    setState(() => _offset = Offset.lerp(_releaseOffset, Offset.zero, _controller.value)!);
  }

  void _onPanStart(DragStartDetails details) {
    _controller.stop(); // 回弹中又抓住 → 停止动画，从当前位置继续拖
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _offset += details.delta); // 跟手
  }

  void _onPanEnd(DragEndDetails details) {
    _releaseOffset = _offset;
    final distance = _offset.distance;
    // 把松手速度（像素/秒）换算成"回弹进度/秒"：朝原点方向的速度分量 ÷ 距离
    final velocity = distance == 0
        ? 0.0
        : -(details.velocity.pixelsPerSecond.dx * _offset.dx + details.velocity.pixelsPerSecond.dy * _offset.dy) /
            (distance * distance);

    final spring = SpringDescription(mass: 1, stiffness: _stiffness, damping: _damping);
    final simulation = SpringSimulation(spring, 0, 1, velocity); // 从 0 弹到 1
    _controller.animateWith(simulation); // ⭐ 按物理模拟推进
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DemoScaffold(
      title: '拖拽 + 弹簧回弹',
      iosAnalogy: '≈ UIPanGesture + usingSpringWithDamping / SwiftUI .spring()',
      tips: const [
        '拖动中直接改位置（跟手）；松手后才交给动画',
        'controller.animateWith(SpringSimulation) 按物理推进，无需 duration',
        '把松手速度传进 simulation，才有"甩"的手感',
      ],
      child: Column(
        children: [
          SizedBox(
            height: 320,
            child: Center(
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Transform.translate(
                  offset: _offset,
                  child: Container(
                    width: 120,
                    height: 160,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26, offset: Offset(0, 6))],
                    ),
                    alignment: Alignment.center,
                    child: Text('拖我\n然后松手', textAlign: TextAlign.center, style: TextStyle(color: scheme.onPrimary)),
                  ),
                ),
              ),
            ),
          ),
          _slider('刚度 stiffness', _stiffness, 50, 500, (v) => setState(() => _stiffness = v)),
          _slider('阻尼 damping', _damping, 2, 40, (v) => setState(() => _damping = v)),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text('$label\n${value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12))),
        Expanded(child: Slider(value: value, min: min, max: max, onChanged: onChanged)),
      ],
    );
  }
}
