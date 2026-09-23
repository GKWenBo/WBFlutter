import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_lab/lessons/l6/l6_platform_view_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  testWidgets('L6 页面能 build 并显示标题与控制条', (tester) async {
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => call.method == 'create' ? 0 : null,
    );
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null));

    await tester.pumpWidget(const MaterialApp(home: L6PlatformViewPage()));
    expect(find.text('L6 PlatformView 视图级混合'), findsOneWidget);
  });
}
