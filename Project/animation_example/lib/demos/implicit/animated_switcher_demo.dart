// =============================================================================
// AnimatedSwitcher —— "换一个子组件"时的过渡动画
//
// 解决什么：child 从 A 换成 B 时，旧的淡出、新的淡入（或自定义缩放/滑动）。
// iOS 对应：UIView.transition(with:duration:options:.transitionCrossDissolve)
//          SwiftUI 的 .transition(.opacity) + .id(x)
//
// ⭐ 最大的坑：AnimatedSwitcher 判断"换没换"是看 runtimeType + key。
//    Text('1') → Text('2') 类型相同、没 key，会被当成"同一个组件更新"→ 不播动画！
//    必须给 child 一个随内容变化的 key：Text('$count', key: ValueKey(count))。
//    这和 SwiftUI 里要 .id(count) 才触发 transition 是一个道理。
// =============================================================================

import 'package:flutter/material.dart';

import '../../widgets/demo_scaffold.dart';

class AnimatedSwitcherDemo extends StatefulWidget {
  const AnimatedSwitcherDemo({super.key});

  @override
  State<AnimatedSwitcherDemo> createState() => _AnimatedSwitcherDemoState();
}

class _AnimatedSwitcherDemoState extends State<AnimatedSwitcherDemo> {
  int _count = 0;
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final big = Theme.of(context).textTheme.displayMedium;

    return DemoScaffold(
      title: 'AnimatedSwitcher',
      iosAnalogy: '≈ UIView.transition(.transitionCrossDissolve) / SwiftUI .transition + .id',
      tips: const [
        '⭐ child 必须带随内容变化的 key（ValueKey），否则不触发动画',
        '默认是淡入淡出，transitionBuilder 可换成缩放/滑动/组合',
        '旧 child 和新 child 会同时存在一段时间（叠在 Stack 里）',
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------- 1. 默认淡入淡出 ----------
          const SectionTitle('1. 默认：淡入淡出'),
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text('$_count', key: ValueKey(_count), style: big),
            ),
          ),

          // ---------- 2. 自定义：数字从下往上滚（滑动 + 淡入） ----------
          const SectionTitle('2. 自定义 transitionBuilder：向上滚动'),
          ClipRect(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  // 新 child 的 animation 是 0→1；旧 child 的 animation 是 1→0（反向播放）。
                  // 新的：begin=(0,1) → 从下方滑到原位；
                  // 旧的：begin=(0,-1)，因为反向播放，实际是从原位滑到上方。
                  // 用 key 区分新旧：新 child 的 key 等于当前值。
                  final isNew = child.key == ValueKey(_count);
                  final offset = Tween<Offset>(
                    begin: isNew ? const Offset(0, 1) : const Offset(0, -1),
                    end: Offset.zero,
                  ).animate(animation);
                  return SlideTransition(
                    position: offset,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Text('$_count', key: ValueKey(_count), style: big),
              ),
            ),
          ),

          // ---------- 3. 图标切换：缩放 ----------
          const SectionTitle('3. 图标切换：缩放弹出'),
          Center(
            child: IconButton(
              iconSize: 48,
              onPressed: () => setState(() => _liked = !_liked),
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                  child: child,
                ),
                // 两个 Icon 类型相同，所以同样要靠 key 区分
                child: _liked
                    ? const Icon(Icons.favorite, color: Colors.red, key: ValueKey('liked'))
                    : const Icon(Icons.favorite_border, key: ValueKey('unliked')),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.tonal(
                onPressed: () => setState(() => _count--),
                child: const Icon(Icons.remove),
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: () => setState(() => _count++),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
