// =============================================================================
// AnimatedBuilder —— 没有现成 XxxTransition 时，自己用动画值拼 UI
//
// 用法：AnimatedBuilder(animation: controller, builder: (ctx, child) => ..., child: 静态子树)
//   - animation 每帧通知 → 只重新执行 builder，页面其它部分不重建
//   - ⭐ child 参数：不随动画变化的子树只构建一次，传进 builder 复用（性能关键）
//
// iOS 对应：CADisplayLink 回调里手动改 layer 属性；
//          AnimatedBuilder 帮你管好了"订阅 + 只刷新局部"。
//
// 对比 setState：在 controller.addListener 里 setState 也能动，但会重建整个页面，不推荐。
// =============================================================================

import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/demo_scaffold.dart';

class AnimatedBuilderDemo extends StatefulWidget {
  const AnimatedBuilderDemo({super.key});

  @override
  State<AnimatedBuilderDemo> createState() => _AnimatedBuilderDemoState();
}

// 两个 controller → 用 TickerProviderStateMixin（不是 Single）
class _AnimatedBuilderDemoState extends State<AnimatedBuilderDemo> with TickerProviderStateMixin {
  // 呼吸灯：1.2 秒来回
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  // 加载转圈：1 秒一圈，线性无限循环
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _breath.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return DemoScaffold(
      title: 'AnimatedBuilder',
      iosAnalogy: '≈ CADisplayLink 每帧改 layer，但只刷新局部',
      tips: const [
        '⭐ 不变的子树放 child 参数，builder 里复用，避免每帧重建',
        '比 addListener + setState 高效：只重建 builder 返回的部分',
        '多个 controller 时用 TickerProviderStateMixin',
      ],
      child: Column(
        children: [
          // ---------- 1. 呼吸灯：阴影 + 缩放随动画变化 ----------
          const SectionTitle('1. 呼吸灯'),
          SizedBox(
            height: 160,
            child: Center(
              child: AnimatedBuilder(
                animation: _breath,
                // 这个 Icon 不随动画变，只构建一次
                child: const Icon(Icons.favorite, color: Colors.white, size: 40),
                builder: (context, child) {
                  final t = Curves.easeInOut.transform(_breath.value);
                  return Container(
                    width: 80 + 10 * t,
                    height: 80 + 10 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.pink,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pink.withValues(alpha: 0.6),
                          blurRadius: 10 + 30 * t,
                          spreadRadius: 2 + 10 * t,
                        ),
                      ],
                    ),
                    child: child, // ← 复用
                  );
                },
              ),
            ),
          ),

          // ---------- 2. 自定义加载：三个点依次跳动 ----------
          const SectionTitle('2. 加载动画：三点跳动'),
          SizedBox(
            height: 60,
            child: AnimatedBuilder(
              animation: _spin,
              builder: (context, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  // 每个点相位错开 1/3 圈，用 sin 做上下跳动
                  final phase = (_spin.value - i / 3) * 2 * pi;
                  final dy = -max(0.0, sin(phase)) * 16;
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  );
                }),
              ),
            ),
          ),

          // ---------- 3. 旋转渐变圈 ----------
          const SectionTitle('3. 旋转渐变加载圈'),
          AnimatedBuilder(
            animation: _spin,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [color.withValues(alpha: 0), color]),
              ),
            ),
            builder: (context, child) => Transform.rotate(
              angle: _spin.value * 2 * pi,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
