// =============================================================================
// AnimatedXxx 合集 —— 每个"布局/样式组件"基本都有一个隐式动画版本
//
// 规律：Opacity → AnimatedOpacity，Align → AnimatedAlign，Padding → AnimatedPadding，
//      Positioned → AnimatedPositioned，DefaultTextStyle → AnimatedDefaultTextStyle，
//      还有 AnimatedRotation / AnimatedScale / AnimatedSlide / AnimatedPhysicalModel ...
// 用法完全一致：原组件参数 + duration (+ curve)，改值 setState 即可。
//
// iOS 对应：UIView.animate 里改 alpha / center / transform。
// =============================================================================

import 'package:flutter/material.dart';

import '../../widgets/demo_scaffold.dart';

class AnimatedWidgetsDemo extends StatefulWidget {
  const AnimatedWidgetsDemo({super.key});

  @override
  State<AnimatedWidgetsDemo> createState() => _AnimatedWidgetsDemoState();
}

class _AnimatedWidgetsDemoState extends State<AnimatedWidgetsDemo> {
  static const _duration = Duration(milliseconds: 500);

  bool _visible = true;
  bool _alignRight = false;
  bool _bigPadding = false;
  bool _moved = false;
  bool _bigText = false;
  bool _turned = false;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final box = Container(width: 60, height: 60, color: color);

    return DemoScaffold(
      title: 'AnimatedXxx 合集',
      iosAnalogy: '≈ UIView.animate 里改 alpha / center / transform',
      tips: const [
        '命名规律：普通组件名前加 Animated，参数一致 + duration',
        'AnimatedOpacity 透明度为 0 时仍占位、仍能点击；要彻底隐藏配合 IgnorePointer/Visibility',
        'AnimatedPositioned 必须放在 Stack 里',
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------- AnimatedOpacity：≈ view.alpha ----------
          _row(
            'AnimatedOpacity',
            () => setState(() => _visible = !_visible),
            AnimatedOpacity(opacity: _visible ? 1 : 0, duration: _duration, child: box),
          ),

          // ---------- AnimatedAlign：在父容器里换对齐位置 ----------
          _row(
            'AnimatedAlign',
            () => setState(() => _alignRight = !_alignRight),
            SizedBox(
              height: 60,
              child: AnimatedAlign(
                alignment: _alignRight ? Alignment.centerRight : Alignment.centerLeft,
                duration: _duration,
                curve: Curves.easeInOut,
                child: box,
              ),
            ),
          ),

          // ---------- AnimatedPadding ----------
          _row(
            'AnimatedPadding',
            () => setState(() => _bigPadding = !_bigPadding),
            ColoredBox(
              color: color.withValues(alpha: 0.15),
              child: AnimatedPadding(
                padding: EdgeInsets.all(_bigPadding ? 32 : 4),
                duration: _duration,
                child: box,
              ),
            ),
          ),

          // ---------- AnimatedPositioned：Stack 里的绝对定位动画 ≈ 改 frame.origin ----------
          _row(
            'AnimatedPositioned',
            () => setState(() => _moved = !_moved),
            SizedBox(
              height: 100,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: _duration,
                    curve: Curves.easeOutBack,
                    left: _moved ? 200 : 0,
                    top: _moved ? 40 : 0,
                    child: box,
                  ),
                ],
              ),
            ),
          ),

          // ---------- AnimatedDefaultTextStyle：字号/颜色/字重动画 ----------
          _row(
            'AnimatedDefaultTextStyle',
            () => setState(() => _bigText = !_bigText),
            AnimatedDefaultTextStyle(
              duration: _duration,
              style: TextStyle(
                fontSize: _bigText ? 32 : 16,
                color: _bigText ? Colors.deepOrange : Colors.black87,
                fontWeight: _bigText ? FontWeight.bold : FontWeight.normal,
              ),
              child: const Text('Hello Flutter'),
            ),
          ),

          // ---------- AnimatedRotation / AnimatedScale：≈ CGAffineTransform ----------
          _row(
            'AnimatedRotation + AnimatedScale',
            () => setState(() => _turned = !_turned),
            Center(
              child: AnimatedRotation(
                turns: _turned ? 0.5 : 0, // 单位是"圈"，0.5 = 180°
                duration: _duration,
                child: AnimatedScale(
                  scale: _turned ? 1.5 : 1,
                  duration: _duration,
                  child: const Icon(Icons.navigation, size: 48),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String title, VoidCallback onTap, Widget demo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SectionTitle(title)),
            TextButton(onPressed: onTap, child: const Text('切换')),
          ],
        ),
        demo,
      ],
    );
  }
}
