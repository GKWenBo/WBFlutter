import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_lab/lessons/l6/native_platform_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('控制器把按钮动作编码成对应的 method call', () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('com.wenbo.native_lab/native_view_7');
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final c = NativeViewController(7);
    await c.setMapType('satellite');
    await c.resetRegion();
    await c.loadUrl('https://dart.dev');
    await c.reload();

    expect(calls[0].method, 'setMapType');
    expect(calls[0].arguments, 'satellite');
    expect(calls[1].method, 'resetRegion');
    expect(calls[2].method, 'loadUrl');
    expect(calls[2].arguments, 'https://dart.dev');
    expect(calls[3].method, 'reload');
  });

  testWidgets('按平台产出对应的原生视图 widget', (tester) async {
    // 拦截 flutter/platform_views 系统通道：让 create 返回一个 viewId，
    // 避免 UiKitView/AndroidView 在无原生宿主的测试环境里抛错。
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => call.method == 'create' ? 0 : null,
    );
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null));

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: NativePlatformView(
        creationParams: const {'lat': 31.0, 'lng': 121.0, 'span': 0.2},
        onCreated: (_) {},
      ),
    ));
    expect(find.byType(UiKitView), findsOneWidget);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: NativePlatformView(
        creationParams: const {'url': 'https://flutter.dev'},
        onCreated: (_) {},
      ),
    ));
    expect(find.byType(AndroidView), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });
}
