import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_lab/lessons/l7/l7_plugin_page.dart';

void main() {
  testWidgets('L7 页面能 build 并显示标题', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: L7PluginPage()));
    expect(find.text('L7 插件：nl_device_kit'), findsOneWidget);
  });
}
