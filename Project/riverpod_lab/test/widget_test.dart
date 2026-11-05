import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_lab/app.dart';

void main() {
  testWidgets('首页展示课程目录', (tester) async {
    // 测试里同样需要 ProviderScope，否则 HomePage 里的 ref.watch 会失败。
    await tester.pumpWidget(const ProviderScope(child: RiverpodLabApp()));

    expect(find.text('Riverpod Lab'), findsOneWidget);
    expect(find.textContaining('S1 · 计数器'), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
  });
}
