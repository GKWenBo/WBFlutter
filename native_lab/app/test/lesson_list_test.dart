import 'package:flutter_test/flutter_test.dart';
import 'package:native_lab/lessons/lesson_registry.dart';
import 'package:native_lab/main.dart';

void main() {
  // 教学点：widget test 类比 iOS 的 XCTest + 一点 UI Test 的混合体——
  // 不起模拟器、不渲染真像素，但真实构建 Widget 树、真实跑手势和动画帧，
  // 所以比 XCUITest 快几个数量级，团队里通常大量写。
  testWidgets('课程列表展示 10 个课时', (tester) async {
    // pumpWidget 类比：把 rootViewController 装上 window 并走完一帧布局。
    await tester.pumpWidget(const NativeLabApp());
    expect(lessonRegistry.length, 10);
    expect(find.text('工程创建与原生工程解剖'), findsOneWidget);
    expect(find.text('MethodChannel：Flutter 调原生'), findsOneWidget);
  });

  testWidgets('点击锁定课时只弹提示，不跳转', (tester) async {
    await tester.pumpWidget(const NativeLabApp());
    // L5 已解锁，锁定样本换成 L6。
    await tester.tap(find.text('PlatformView：视图级混合'));
    await tester.pump(); // 推一帧，让 SnackBar 开始入场
    expect(find.text('先完成前面的课时，再解锁 L6'), findsOneWidget);
  });

  testWidgets('点击 L0 进入原生工程解剖页', (tester) async {
    await tester.pumpWidget(const NativeLabApp());
    await tester.tap(find.text('工程创建与原生工程解剖'));
    await tester.pumpAndSettle(); // 等 push 转场动画走完（类比等 pushViewController 动画结束）
    expect(find.text('L0 原生工程解剖'), findsOneWidget);
  });
}
