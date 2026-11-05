// =============================================================================
// AnimatedContainer —— 隐式动画的代表
//
// 解决什么：让一个盒子的 宽高/颜色/圆角/边距/阴影 等属性"平滑地"变到新值。
// iOS 对应：UIView.animate(withDuration:) { view.frame = ...; view.backgroundColor = ... }
//          SwiftUI 的 .animation(.easeInOut, value: x)
// 差异：iOS 是"在闭包里改属性"；Flutter 是"setState 改状态 → 重新 build 出新属性值"，
//      AnimatedContainer 发现新旧值不同，自己在内部从旧值补间到新值。
//
// 什么时候用：属性 A → B 的一次性过渡，不需要暂停/循环/反向控制。
// 什么时候不用：要循环、要手动控制进度、要和手势联动 → 用显式动画（AnimationController）。
// =============================================================================

import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/demo_scaffold.dart';

class AnimatedContainerDemo extends StatefulWidget {
  const AnimatedContainerDemo({super.key});

  @override
  State<AnimatedContainerDemo> createState() => _AnimatedContainerDemoState();
}

class _AnimatedContainerDemoState extends State<AnimatedContainerDemo> {
  final _random = Random();

  // 这些就是"目标值"。改它们 + setState，AnimatedContainer 自己会动过去。
  double _width = 120;
  double _height = 120;
  Color _color = Colors.indigo;
  double _radius = 16;

  // 可切换的曲线，演示 curve 参数对手感的影响。
  static const _curves = <String, Curve>{
    'easeInOut': Curves.easeInOut,
    'easeOutBack': Curves.easeOutBack,
    'elasticOut': Curves.elasticOut,
    'bounceOut': Curves.bounceOut,
    'linear': Curves.linear,
  };
  String _curveName = 'easeInOut';

  void _randomize() {
    setState(() {
      _width = 60 + _random.nextDouble() * 200;
      _height = 60 + _random.nextDouble() * 200;
      _color = Color.fromARGB(255, _random.nextInt(256), _random.nextInt(256), _random.nextInt(256));
      _radius = _random.nextDouble() * 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'AnimatedContainer',
      iosAnalogy: '≈ UIView.animate { 改 frame / backgroundColor / cornerRadius }',
      tips: const [
        '只需 setState 改目标值，动画由组件内部自动完成',
        'duration 必填；curve 决定手感，弹性曲线可能"冲过头"',
        '动画途中再次改值，会从当前值平滑地转向新目标，不会跳',
      ],
      child: Column(
        children: [
          SizedBox(
            height: 280,
            child: Center(
              // ⭐ 核心：把 Container 换成 AnimatedContainer，再给 duration/curve 即可。
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: _curves[_curveName]!,
                width: _width,
                height: _height,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(_radius),
                  boxShadow: [
                    BoxShadow(color: _color.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8)),
                  ],
                ),
                // 动画结束回调，≈ UIView.animate 的 completion
                onEnd: () => debugPrint('AnimatedContainer 动画结束'),
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final name in _curves.keys)
                ChoiceChip(
                  label: Text(name),
                  selected: _curveName == name,
                  onSelected: (_) => setState(() => _curveName = name),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _randomize,
            icon: const Icon(Icons.shuffle),
            label: const Text('随机变化'),
          ),
        ],
      ),
    );
  }
}
