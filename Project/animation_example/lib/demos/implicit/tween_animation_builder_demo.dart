// =============================================================================
// TweenAnimationBuilder —— "自定义隐式动画"的万能钥匙
//
// 解决什么：没有现成 AnimatedXxx 的属性（进度环的进度、数字、渐变角度……）也想做隐式动画。
// 用法：给一个 Tween(end: 目标值)，builder 里拿到"当前插值"去画 UI。
//      end 变了 → 自动从"当前值"补间到新 end。
//
// iOS 对应：没有完全对等的 API。类似 SwiftUI 的 Animatable / animatableData，
//          或用 CADisplayLink 手写插值。
//
// 注意：begin 只在第一次 build 时生效；之后每次 end 变化都从"当前值"出发。
// =============================================================================

import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/demo_scaffold.dart';

class TweenAnimationBuilderDemo extends StatefulWidget {
  const TweenAnimationBuilderDemo({super.key});

  @override
  State<TweenAnimationBuilderDemo> createState() => _TweenAnimationBuilderDemoState();
}

class _TweenAnimationBuilderDemoState extends State<TweenAnimationBuilderDemo> {
  double _progress = 0.3;
  int _balance = 1000;
  final _random = Random();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DemoScaffold(
      title: 'TweenAnimationBuilder',
      iosAnalogy: '≈ SwiftUI Animatable / 手写 CADisplayLink 插值',
      tips: const [
        '没有现成 AnimatedXxx 时的首选，不用自己管 Controller',
        'begin 只在首次生效；之后从当前值补间到新的 end',
        '不变的子树放 child 参数里，builder 里直接复用，避免每帧重建',
      ],
      child: Column(
        children: [
          // ---------- 1. 进度环 ----------
          const SectionTitle('1. 进度环'),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _progress), // end 一变就开始补间
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              // value 是每一帧的当前插值
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(value: value, strokeWidth: 10),
                  ),
                  Text('${(value * 100).round()}%', style: textTheme.headlineMedium),
                ],
              );
            },
          ),
          Slider(value: _progress, onChanged: (v) => setState(() => _progress = v)),

          // ---------- 2. 数字滚动（金额跳动） ----------
          const SectionTitle('2. 数字滚动'),
          TweenAnimationBuilder<int>(
            // IntTween：插值结果自动取整
            tween: IntTween(begin: 0, end: _balance),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOut,
            builder: (context, value, child) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                child!, // 静态的"¥"图标，从 child 参数传进来，不会每帧重建
                Text('$value', style: textTheme.displaySmall),
              ],
            ),
            child: const Icon(Icons.currency_yen, size: 36),
          ),
          TextButton(
            onPressed: () => setState(() => _balance = _random.nextInt(100000)),
            child: const Text('随机金额'),
          ),

          // ---------- 3. 颜色补间 ----------
          const SectionTitle('3. ColorTween：随进度变色'),
          TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: Color.lerp(Colors.green, Colors.red, _progress)),
            duration: const Duration(milliseconds: 500),
            builder: (context, color, _) => Icon(Icons.thermostat, size: 64, color: color),
          ),
        ],
      ),
    );
  }
}
