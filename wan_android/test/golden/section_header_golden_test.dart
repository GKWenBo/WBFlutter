// M11 教学重点：golden 测试 = Flutter 版"快照测试"。
//
// iOS 对照：≈ FBSnapshotTestCase / swift-snapshot-testing——
//   把 Widget 渲染成 PNG，和事先生成的"基准图"逐像素比对，任何视觉回归都会让测试失败。
//
// 怎么跑：
//   1. 首次/改了 UI 后生成基准图： flutter test --update-goldens test/golden/
//   2. 之后普通跑： flutter test test/golden/  ——像素不一致就 fail，diff 图会写到 failures/ 目录。
//
// 坑：
//   - 测试环境默认用 Ahem 占位字体（每个字渲染成方块），所以基准图里文字是"█"而不是真汉字——
//     这是刻意的：避免不同机器字体差异导致 golden 到处失败。要看真字体得额外加载字体，一般不必。
//   - 基准图**必须提交进 git**，否则别人跑测试没有比对基准。
//   - 跨平台像素可能有细微差异；团队通常固定在 CI 的同一套环境生成 golden。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wan_android/features/products/presentation/widgets/section_header.dart';

void main() {
  // 固定一个手机宽度的画布，让每次渲染尺寸一致（golden 对尺寸敏感）。
  Widget host(Widget child) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(child: SizedBox(width: 375, child: child)),
    ),
  );

  testWidgets('SectionHeader 带「查看全部」的样子', (tester) async {
    await tester.pumpWidget(host(SectionHeader(title: '热门推荐', onMore: () {})));
    await expectLater(
      find.byType(SectionHeader),
      matchesGoldenFile('goldens/section_header_with_more.png'),
    );
  });

  testWidgets('SectionHeader 不带「查看全部」的样子（onMore 为 null 时右侧按钮消失）', (
    tester,
  ) async {
    await tester.pumpWidget(host(const SectionHeader(title: '猜你喜欢')));
    await expectLater(
      find.byType(SectionHeader),
      matchesGoldenFile('goldens/section_header_plain.png'),
    );
  });
}
