// =============================================================================
// AnimationController + Tween + CurvedAnimation —— 显式动画三件套
//
// 1) AnimationController：时间驱动器。在 duration 内把 value 从 0.0 推到 1.0（每帧回调）。
//    需要一个 TickerProvider（vsync），通过 `with SingleTickerProviderStateMixin` 获得，
//    作用是：页面不可见时自动暂停 ticker，省电。
// 2) CurvedAnimation：把线性的 0→1 映射成曲线（缓入缓出、弹性……）。
// 3) Tween：把 0→1 映射到你真正需要的值域（0→300 像素、红→蓝、0°→360°）。
//    组合：controller → CurvedAnimation → Tween.animate(...) → Animation<T>
//
// iOS 对应：
//   AnimationController ≈ CADisplayLink + 手写进度，或 UIViewPropertyAnimator（可暂停/反向/fractionComplete）
//   Tween + Curve        ≈ CABasicAnimation 的 fromValue/toValue + timingFunction
//
// ⭐ 必须在 dispose() 里调用 controller.dispose()，否则 Ticker 泄漏并报错。
// =============================================================================

import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/demo_scaffold.dart';

class AnimationControllerDemo extends StatefulWidget {
  const AnimationControllerDemo({super.key});

  @override
  State<AnimationControllerDemo> createState() => _AnimationControllerDemoState();
}

// SingleTickerProviderStateMixin：只有 1 个 controller 时用；多个用 TickerProviderStateMixin。
class _AnimationControllerDemoState extends State<AnimationControllerDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _position; // 0 → 1（经过曲线），用来算水平位置
  late final Animation<Color?> _color;

  AnimationStatus _status = AnimationStatus.dismissed;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, // this 就是 TickerProvider
      duration: const Duration(milliseconds: 1500),
    )
      // 监听状态：dismissed(在起点) / forward / reverse / completed(在终点)
      ..addStatusListener((status) => setState(() => _status = status));

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
      reverseCurve: Curves.easeIn, // 反向时可以用不同曲线
    );
    _position = curved; // 直接用曲线后的 0→1
    _color = ColorTween(begin: Colors.indigo, end: Colors.pink).animate(curved);
  }

  @override
  void dispose() {
    _controller.dispose(); // ⭐ 必须释放
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'AnimationController',
      iosAnalogy: '≈ UIViewPropertyAnimator（可暂停/反向/拖进度）+ CABasicAnimation',
      tips: const [
        'with SingleTickerProviderStateMixin 提供 vsync；多个 controller 用 TickerProviderStateMixin',
        '⭐ dispose() 里必须 controller.dispose()',
        'controller.value 可直接赋值 → 拖动进度条手动控制（≈ fractionComplete）',
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 120,
            // AnimatedBuilder：controller 每帧通知 → 只重建 builder 里这一小块
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    const size = 64.0;
                    final maxLeft = constraints.maxWidth - size;
                    return Stack(
                      children: [
                        Positioned(
                          left: maxLeft * _position.value,
                          top: 28,
                          child: Transform.rotate(
                            angle: _position.value * 2 * pi, // 一圈
                            child: Container(
                              width: size,
                              height: size,
                              decoration: BoxDecoration(
                                color: _color.value,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Column(
              children: [
                Text('status: ${_status.name}    value: ${_controller.value.toStringAsFixed(2)}'),
                // 拖动 Slider 直接改 controller.value，实现"手动控制进度"
                Slider(
                  value: _controller.value,
                  onChanged: (v) {
                    _controller.stop();
                    _controller.value = v;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: () => _controller.forward(), child: const Text('forward')),
              FilledButton(onPressed: () => _controller.reverse(), child: const Text('reverse')),
              FilledButton.tonal(
                onPressed: () => _controller.repeat(reverse: true), // 来回循环
                child: const Text('repeat(reverse)'),
              ),
              FilledButton.tonal(
                onPressed: () => _controller.stop(),
                child: const Text('stop'),
              ),
              OutlinedButton(
                onPressed: () => _controller.reset(), // 回到 0，不播动画
                child: const Text('reset'),
              ),
              OutlinedButton(
                // animateTo：动画到指定进度
                onPressed: () => _controller.animateTo(0.5, curve: Curves.easeOut),
                child: const Text('animateTo(0.5)'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
