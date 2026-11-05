// =============================================================================
// AnimatedCrossFade / AnimatedSize —— 展开收起的两种写法
//
// AnimatedCrossFade：在"两个固定的子组件"之间交叉淡入淡出，同时把尺寸从 A 补间到 B。
// AnimatedSize：子组件自身尺寸变化时（比如文字从 2 行变全文），自动把尺寸变化做成动画。
//
// iOS 对应：UIStackView 里 isHidden = true 包在 UIView.animate 里 + layoutIfNeeded()；
//          SwiftUI 里 if expanded { ... } 配合 withAnimation。
//
// 选择：只有两种状态 → AnimatedCrossFade；内容尺寸任意变化 → AnimatedSize。
// =============================================================================

import 'package:flutter/material.dart';

import '../../widgets/demo_scaffold.dart';

class AnimatedCrossFadeDemo extends StatefulWidget {
  const AnimatedCrossFadeDemo({super.key});

  @override
  State<AnimatedCrossFadeDemo> createState() => _AnimatedCrossFadeDemoState();
}

class _AnimatedCrossFadeDemoState extends State<AnimatedCrossFadeDemo> {
  bool _showSecond = false;
  bool _expanded = false;

  static const _longText = 'Flutter 的动画系统分为两大类：隐式动画和显式动画。'
      '隐式动画只要改变目标值，框架就会自动补间；'
      '显式动画需要自己持有 AnimationController，可以精确控制播放、暂停、反向、循环。'
      '大多数业务场景用隐式动画就够了，只有需要循环、手势联动、精确编排时才需要显式动画。'
      '理解了这两者的边界，就能在写需求时快速做出选型。';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DemoScaffold(
      title: 'CrossFade / Size',
      iosAnalogy: '≈ UIView.animate { isHidden = ...; layoutIfNeeded() }',
      tips: const [
        'AnimatedCrossFade 两个 child 尺寸不同时，会同时补间高度',
        'AnimatedSize 只关心"自己尺寸变了"，内容怎么变都行',
        '展开时被裁剪的内容要配合 ClipRect / alignment 调整从哪边展开',
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------- AnimatedCrossFade ----------
          const SectionTitle('AnimatedCrossFade：登录 ↔ 已登录'),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 400),
            // crossFadeState 决定显示哪一个
            crossFadeState: _showSecond ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: Card(
              child: ListTile(
                leading: const Icon(Icons.login),
                title: const Text('未登录'),
                subtitle: const Text('点按钮模拟登录'),
                tileColor: scheme.surfaceContainerHighest,
              ),
            ),
            secondChild: Card(
              color: scheme.primaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(radius: 32, child: Icon(Icons.person, size: 32)),
                    SizedBox(height: 8),
                    Text('欢迎回来，Wenbo'),
                    Text('第二个 child 更高，高度也会平滑过渡'),
                  ],
                ),
              ),
            ),
          ),
          Align(
            child: TextButton(
              onPressed: () => setState(() => _showSecond = !_showSecond),
              child: Text(_showSecond ? '退出登录' : '登录'),
            ),
          ),

          // ---------- AnimatedSize ----------
          const SectionTitle('AnimatedSize：文字展开 / 收起'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 文字 maxLines 变化 → 高度变化 → AnimatedSize 把高度变化做成动画
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter, // 从顶部往下展开
                    child: Text(
                      _longText,
                      maxLines: _expanded ? null : 2,
                      overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? '收起' : '展开全文'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
