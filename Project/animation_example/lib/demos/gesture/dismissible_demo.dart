// =============================================================================
// 滑动删除 & 卡片 3D 翻转
//
// 1) Dismissible：左右滑动移除一行，自带滑出 + 高度收起动画。
//    iOS 对应：tableView 的 trailingSwipeActionsConfiguration / .swipeActions（完全滑动删除）
//    坑：key 必须唯一且稳定（用数据 id），并且 onDismissed 里必须同步删掉数据，否则报错
//       "A dismissed Dismissible widget is still part of the tree"。
//
// 2) 3D 翻转：Transform + Matrix4.rotationY + 透视
//    iOS 对应：CATransform3DRotate + transform.m34 = -1/500（透视）
//             或 UIView.transition(with:options:.transitionFlipFromLeft)
//    要点：转过 90° 后切换显示背面，并把背面再翻转 180°，否则背面内容是镜像的。
// =============================================================================

import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/demo_scaffold.dart';

class DismissibleDemo extends StatefulWidget {
  const DismissibleDemo({super.key});

  @override
  State<DismissibleDemo> createState() => _DismissibleDemoState();
}

class _DismissibleDemoState extends State<DismissibleDemo> {
  final List<String> _mails = List.generate(5, (i) => '邮件 ${i + 1}');

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: '滑动删除 & 翻转',
      iosAnalogy: '≈ swipeActions 删除 / CATransform3D 翻转 + m34 透视',
      tips: const [
        'Dismissible 的 key 必须唯一稳定；onDismissed 里必须同步删数据',
        'confirmDismiss 返回 false 可以取消删除（弹框确认）',
        '3D 翻转需要 setEntry(3, 2, 0.001) 加透视，否则看起来只是变窄',
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('1. Dismissible 滑动删除（左滑删除，右滑归档需确认）'),
          for (final mail in _mails)
            Dismissible(
              key: ValueKey(mail), // ⭐ 唯一稳定
              // 右滑（startToEnd）背景
              background: _swipeBg(Colors.green, Icons.archive, Alignment.centerLeft),
              // 左滑（endToStart）背景
              secondaryBackground: _swipeBg(Colors.red, Icons.delete, Alignment.centerRight),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.endToStart) return true; // 删除直接通过
                // 归档弹框确认
                return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('归档 $mail？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('归档')),
                        ],
                      ),
                    ) ??
                    false;
              },
              onDismissed: (direction) {
                setState(() => _mails.remove(mail)); // ⭐ 同步删数据
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已移除 $mail')));
              },
              child: Card(child: ListTile(leading: const Icon(Icons.mail_outline), title: Text(mail))),
            ),
          if (_mails.isEmpty)
            TextButton(
              onPressed: () => setState(() => _mails.addAll(List.generate(5, (i) => '邮件 ${i + 1}'))),
              child: const Text('恢复数据'),
            ),
          const SectionTitle('2. 卡片 3D 翻转（点击卡片）'),
          const Center(child: _FlipCard()),
        ],
      ),
    );
  }

  Widget _swipeBg(Color color, IconData icon, Alignment alignment) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: color,
      alignment: alignment,
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _FlipCard extends StatefulWidget {
  const _FlipCard();

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    // 根据当前状态决定正翻还是反翻
    _controller.isCompleted || _controller.status == AnimationStatus.forward
        ? _controller.reverse()
        : _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final angle = Curves.easeInOut.transform(_controller.value) * pi; // 0 → π
          final showBack = angle > pi / 2; // 过了 90° 显示背面
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // ⭐ 透视 ≈ m34 = -1/1000
              ..rotateY(angle),
            child: showBack
                // 背面再转 180°，抵消镜像
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(pi),
                    child: _face('背面', Colors.deepPurple, Icons.lock_open),
                  )
                : _face('正面', Colors.teal, Icons.lock),
          );
        },
      ),
    );
  }

  Widget _face(String text, Color color, IconData icon) {
    return Container(
      width: 200,
      height: 120,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 36),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
    );
  }
}
