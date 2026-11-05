// =============================================================================
// CustomPainter + AnimationController —— 自绘动画
//
// 思路：controller 产生 0→1 的进度，Painter 根据进度在 Canvas 上画图。
//   ⭐ 把 controller 传给 CustomPainter 的 `repaint` 参数（super(repaint: animation)），
//     动画每帧只触发 paint()，不走 build、不走 layout，性能最好。
//
// iOS 对应：
//   进度环 ≈ CAShapeLayer + CABasicAnimation(keyPath: "strokeEnd")
//   波浪   ≈ CADisplayLink 每帧重新生成 UIBezierPath 赋给 shapeLayer.path
//   Canvas ≈ CGContext / UIBezierPath；Paint ≈ 设置 strokeColor/lineWidth/lineCap
// =============================================================================

import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/demo_scaffold.dart';

class CustomPainterDemo extends StatefulWidget {
  const CustomPainterDemo({super.key});

  @override
  State<CustomPainterDemo> createState() => _CustomPainterDemoState();
}

class _CustomPainterDemoState extends State<CustomPainterDemo> with TickerProviderStateMixin {
  // 进度环：一次性画到底
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  // ⭐ CurvedAnimation 会监听 parent，作为字段创建一次，不要在 build 里每次 new
  late final Animation<double> _ringCurved = CurvedAnimation(parent: _ring, curve: Curves.easeOutCubic);

  // 波浪：无限循环相位
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _ring.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return DemoScaffold(
      title: 'CustomPainter 动画',
      iosAnalogy: '≈ CAShapeLayer strokeEnd 动画 / CADisplayLink 重绘 path',
      tips: const [
        '⭐ super(repaint: animation)：每帧只重绘，不重建 Widget',
        'shouldRepaint 判断"配置"是否变化；动画驱动交给 repaint',
        '复杂静态图形外面包 RepaintBoundary，隔离重绘范围',
      ],
      child: Column(
        children: [
          const SectionTitle('1. 进度环（strokeEnd）'),
          GestureDetector(
            onTap: () => _ring.forward(from: 0),
            child: CustomPaint(
              size: const Size(160, 160),
              painter: _RingPainter(
                progress: _ringCurved,
                color: color,
              ),
            ),
          ),
          const Text('点击圆环重播', style: TextStyle(fontSize: 12)),
          const SectionTitle('2. 水波纹'),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _WavePainter(phase: _wave, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color}) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round; // ≈ lineCap = .round

    // 底环
    canvas.drawCircle(center, radius, paint..color = color.withValues(alpha: 0.15));
    // 进度弧：从 12 点钟方向(-π/2) 开始，扫过 2π * progress
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress.value,
      false,
      paint..color = color,
    );
    // 中间百分比文字
    final tp = TextPainter(
      text: TextSpan(
        text: '${(progress.value * 100).round()}%',
        style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.color != color || oldDelegate.progress != progress;
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.phase, required this.color}) : super(repaint: phase);

  final Animation<double> phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color.withValues(alpha: 0.08));
    // 两层波浪，相位和振幅不同，叠加出层次感
    _drawWave(canvas, size, amplitude: 12, offset: 0, color: color.withValues(alpha: 0.4));
    _drawWave(canvas, size, amplitude: 8, offset: pi, color: color.withValues(alpha: 0.7));
  }

  void _drawWave(Canvas canvas, Size size, {required double amplitude, required double offset, required Color color}) {
    final baseY = size.height * 0.5;
    final shift = phase.value * 2 * pi + offset;
    final path = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 4) {
      // y = A·sin(kx + φ)，φ 随时间变化 → 波浪向右移动
      final y = baseY + amplitude * sin(x / size.width * 2 * pi * 1.5 + shift);
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => oldDelegate.color != color || oldDelegate.phase != phase;
}
