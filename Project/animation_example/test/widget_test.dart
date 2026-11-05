// 冒烟测试：首页列出所有 Demo，每个 Demo 页都能打开、跑若干帧不抛异常。

import 'package:animation_example/catalog.dart';
import 'package:animation_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('首页渲染所有分类', (tester) async {
    await tester.pumpWidget(const AnimationExampleApp());
    expect(find.text('Flutter 常用动画'), findsOneWidget);
    expect(find.text(demoCategories.first.name), findsOneWidget);
  });

  for (final category in demoCategories) {
    for (final entry in category.entries) {
      testWidgets('打开 Demo：${entry.title}', (tester) async {
        // 很多 Demo 是 repeat() 无限动画，不能用 pumpAndSettle，手动推进若干帧
        await tester.pumpWidget(MaterialApp(home: Builder(builder: entry.builder)));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
        expect(find.byType(Scaffold), findsWidgets);
      });
    }
  }
}
