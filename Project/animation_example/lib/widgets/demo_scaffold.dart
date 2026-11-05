import 'package:flutter/material.dart';

/// 所有 Demo 页的统一外壳。
///
/// 结构：AppBar + 顶部「要点说明卡」+ 内容区。
/// 说明卡里放：iOS 类比、2~3 条要点/坑，方便边看效果边回顾知识点。
///
/// 对应 iOS：相当于一个 BaseViewController，子类只管填 content。
class DemoScaffold extends StatelessWidget {
  const DemoScaffold({
    super.key,
    required this.title,
    required this.iosAnalogy,
    required this.tips,
    required this.child,
    this.scrollable = true,
  });

  final String title;

  /// 一句话 iOS 类比，例如「≈ UIView.animate」。
  final String iosAnalogy;

  /// 要点 / 易踩的坑，每条一行。
  final List<String> tips;

  /// Demo 主体内容。
  final Widget child;

  /// 内容是否包在 SingleChildScrollView 里。
  /// 内容自带滚动（ListView / AnimatedList）时要传 false，否则会出现嵌套滚动的约束报错。
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TipsCard(iosAnalogy: iosAnalogy, tips: tips),
        if (scrollable)
          Padding(padding: const EdgeInsets.all(16), child: child)
        else
          Expanded(child: child),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: scrollable ? SingleChildScrollView(child: body) : body,
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.iosAnalogy, required this.tips});

  final String iosAnalogy;
  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_iphone, size: 18, color: scheme.onSecondaryContainer),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    iosAnalogy,
                    style: textTheme.titleSmall?.copyWith(color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final tip in tips)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• $tip',
                  style: textTheme.bodySmall?.copyWith(color: scheme.onSecondaryContainer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Demo 内部的小节标题，用来在一页里分隔多个示例。
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
