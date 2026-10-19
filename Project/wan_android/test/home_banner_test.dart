import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wan_android/features/products/presentation/widgets/home_banner.dart';

const urls = ['http://x/one.png', 'http://x/two.png', 'http://x/three.png'];
Widget banner({List<String> images = urls, bool enabled = true}) => MaterialApp(
  home: TickerMode(
    enabled: enabled,
    child: HomeBanner(imageUrls: images),
  ),
);
int activeDot(WidgetTester tester) => tester
    .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
    .toList()
    .indexWhere((dot) => dot.constraints?.maxWidth == 18);
Future<void> advance(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('自动连续翻页，最后一张继续同方向切回第一张', (tester) async {
    await tester.pumpWidget(banner());
    expect(activeDot(tester), 0);
    for (final index in [1, 2, 0, 1]) {
      await advance(tester);
      expect(activeDot(tester), index);
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('第一张向右滑动可以看到最后一张', (tester) async {
    await tester.pumpWidget(banner());
    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(activeDot(tester), 2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('隐藏 Tab 时暂停，恢复后重新计时', (tester) async {
    await tester.pumpWidget(banner());
    await tester.pumpWidget(banner(enabled: false));
    await tester.pump(const Duration(seconds: 10));
    expect(activeDot(tester), 0);
    await tester.pumpWidget(banner());
    await advance(tester);
    expect(activeDot(tester), 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('空列表和单图保持稳定且不启动轮播', (tester) async {
    await tester.pumpWidget(banner(images: []));
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(PageView), findsNothing);
    await tester.pumpWidget(banner(images: [urls.first]));
    await tester.pump(const Duration(seconds: 10));
    expect(activeDot(tester), 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('图片列表变化后重置页码并继续自动轮播', (tester) async {
    await tester.pumpWidget(banner());
    await tester.pumpWidget(banner(images: urls.take(2).toList()));
    await tester.pump();
    expect(activeDot(tester), 0);
    await advance(tester);
    expect(activeDot(tester), 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('手指按住暂停，手动滑动后重新等待完整间隔', (tester) async {
    await tester.pumpWidget(banner());
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(activeDot(tester), 0);
    await gesture.moveBy(const Offset(-600, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(activeDot(tester), 1);
    await tester.pump(const Duration(seconds: 2));
    expect(activeDot(tester), 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(activeDot(tester), 2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('进入后台暂停，回到前台恢复', (tester) async {
    await tester.pumpWidget(banner());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(activeDot(tester), 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await advance(tester);
    expect(activeDot(tester), 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('多指触摸时全部手指释放后才恢复轮播', (tester) async {
    await tester.pumpWidget(banner());
    // 隔离指针暂停策略，不让 PageView 自身的滚动状态掩盖提前恢复的计时器。
    final listener = tester.widget<Listener>(
      find
          .ancestor(of: find.byType(PageView), matching: find.byType(Listener))
          .first,
    );
    listener.onPointerDown!(const PointerDownEvent(pointer: 1));
    listener.onPointerDown!(const PointerDownEvent(pointer: 2));
    listener.onPointerUp!(const PointerUpEvent(pointer: 2));
    await advance(tester);
    expect(activeDot(tester), 0);
    listener.onPointerUp!(const PointerUpEvent(pointer: 1));
    await advance(tester);
    expect(activeDot(tester), 1);
    await tester.pumpWidget(const SizedBox());
  });
}
