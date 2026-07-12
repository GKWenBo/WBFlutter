import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/app/app.dart';

void main() {
  testWidgets('首页列出五个版本；点上锁项弹 SnackBar 提示解锁课时', (tester) async {
    await tester.pumpWidget(const StateLabApp());

    // 断言完整标题（CircleAvatar 里也有 'v0' 字样，textContaining 会命中两处）
    expect(find.text('v0 · setState 基线版'), findsOneWidget);
    expect(find.text('v1 · Provider'), findsOneWidget);
    expect(find.text('v2 · Bloc'), findsOneWidget);
    expect(find.text('v3 · GetX'), findsOneWidget);
    expect(find.text('v4 · Riverpod（结课作业）'), findsOneWidget);

    // v1 已在 S2 解锁，上锁示例换 v2
    await tester.tap(find.text('v2 · Bloc'));
    await tester.pump();
    expect(find.textContaining('S3 解锁'), findsOneWidget);
  });

  testWidgets('v1 已解锁：点卡片推进 Provider 版列表页', (tester) async {
    await tester.pumpWidget(const StateLabApp());
    await tester.tap(find.text('v1 · Provider'));
    await tester.pumpAndSettle();
    // 真实 Dio 在测试环境会秒收 400 → 页面落在错误态，但 AppBar 已是 v1
    expect(find.text('MiniShop · v1 Provider'), findsOneWidget);
  });
}
