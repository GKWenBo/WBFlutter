// =============================================================================
// Curves 曲线画廊 —— 选曲线时的"看图说话"
//
// Curve 就是一个函数 f(t)：输入时间进度 t∈[0,1]，输出动画进度。
//   linear：f(t)=t；easeIn：先慢后快；easeOut：先快后慢；
//   easeOutBack / elasticOut：会冲过 1 再回来（输出可能 >1）。
//
// iOS 对应：
//   Curves.easeIn/easeOut/easeInOut ≈ UIView.AnimationOptions.curveEaseIn/Out/InOut
//   Cubic(a,b,c,d)                  ≈ CAMediaTimingFunction(controlPoints:)
//   elasticOut / 物理弹簧           ≈ usingSpringWithDamping
//
// 本页：左边用 CustomPainter 画出曲线形状，右边一个小球按该曲线运动，直观对比。
// =============================================================================

import 'package:flutter/material.dart';

import '../../widgets/demo_scaffold.dart';

class CurvesGalleryDemo extends StatefulWidget {
  const CurvesGalleryDemo({super.key});

  @override
  State<CurvesGalleryDemo> createState() => _CurvesGalleryDemoState();
}

class _CurvesGalleryDemoState extends State<CurvesGalleryDemo> with SingleTickerProviderStateMixin {
  static const _curves = <String, Curve>{
    'linear': Curves.linear,
    'easeIn': Curves.easeIn,
    'easeOut': Curves.easeOut,
    'easeInOut': Curves.easeInOut,
    'fastOutSlowIn': Curves.fastOutSlowIn, // Material 推荐
    'easeOutCubic': Curves.easeOutCubic,
    'easeOutBack': Curves.easeOutBack,
    'elasticOut': Curves.elasticOut,
    'bounceOut': Curves.bounceOut,
    'decelerate': Curves.decelerate,
    'Cubic(0.68,-0.6,0.32,1.6)': Cubic(0.68, -0.6, 0.32, 1.6), // 自定义贝塞尔
  };

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(); // 只正向循环，便于对比"起步/收尾"

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return DemoScaffold(
      title: 'Curves 曲线画廊',
      iosAnalogy: '≈ CAMediaTimingFunction / UIView curveEaseInOut',
      tips: const [
        '日常 UI 过渡优先 easeInOut / fastOutSlowIn / easeOutCubic',
        'easeOutBack、elasticOut 输出会 >1，注意 Opacity 等不能越界的属性会报错',
        '自定义贝塞尔：Cubic(x1, y1, x2, y2)，可直接用 cubic-bezier.com 调参',
      ],
      child: Column(
        children: [
          for (final entry in _curves.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 120, child: Text(entry.key, style: const TextStyle(fontSize: 12))),
                  // 曲线形状缩略图
                  CustomPaint(
                    size: const Size(48, 36),
                    painter: _CurvePainter(entry.value, color),
                  ),
                  const SizedBox(width: 12),
                  // 小球按曲线运动
                  Expanded(
                    child: SizedBox(
                      height: 24,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final t = entry.value.transform(_controller.value);
                          // Align.x 范围 -1~1，把 0~1 映射过去；弹性曲线可能略超出边界
                          return Align(alignment: Alignment(t * 2 - 1, 0), child: child);
                        },
                        child: CircleAvatar(radius: 10, backgroundColor: color),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 把 Curve 的 f(t) 画成折线。
class _CurvePainter extends CustomPainter {
  _CurvePainter(this.curve, this.color);

  final Curve curve;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 边框
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.grey.shade300,
    );
    final path = Path();
    const steps = 40;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      // y 轴向下为正，所以用 (1 - f(t)) 翻转
      final point = Offset(t * size.width, (1 - curve.transform(t)) * size.height);
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_CurvePainter oldDelegate) => oldDelegate.curve != curve || oldDelegate.color != color;
}
