// Widget 测试 ≈ iOS 的 XCUITest，但快得多：不启模拟器，在内存里渲染 Widget 树后断言。
// 这里先放一个最小冒烟测试：App 能正常构建，且底部 4 个 Tab 标签都在。
// （M11 会专门讲 unit / widget / integration 三层测试。）

import 'package:flutter_test/flutter_test.dart';

import 'package:wan_android/app/app.dart';

void main() {
  testWidgets('App 启动后底部 4 个 Tab 都存在', (WidgetTester tester) async {
    // 构建整个 App 并渲染一帧。
    await tester.pumpWidget(const WanShopApp());

    // 底部导航的 4 个标签应该都能找到。
    // 用 findsWidgets（≥1）而非 findsOneWidget：因为 IndexedStack 会把所有 Tab 页面都构建出来，
    // 文案可能在多处出现。
    expect(find.text('首页'), findsWidgets);
    expect(find.text('分类'), findsWidgets);
    expect(find.text('购物车'), findsWidgets);
    expect(find.text('我的'), findsWidgets);
  });
}
