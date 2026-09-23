import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_lab/lessons/l2/analytics_bridge.dart';
import 'package:native_lab/lessons/l2/analytics_event.dart';
import 'package:native_lab/lessons/l2/l2_analytics_page.dart';

void main() {
  // channel 通信要走 binary messenger，测试环境先把 binding 立起来（同 L1）。
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockNative(Future<Object?>? Function(MethodCall call)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AnalyticsBridge.channel, handler);
  }

  tearDown(() => mockNative(null));

  test('复杂事件：嵌套 Map/List/多种数字类型无损传给原生', () async {
    Map<Object?, Object?>? received;
    mockNative((call) async {
      expect(call.method, 'logEvent');
      // 教学点：原生侧收到的参数就是 codec 解码后的裸结构，
      // Map 的键值静态类型都是 Object?（Dart 侧同理，要 cast 才收窄）。
      received = call.arguments as Map<Object?, Object?>;
      return 1; // 原生回自增序号
    });

    final seq = await AnalyticsBridge.logEvent(
      const AnalyticsEvent(
        name: 'purchase',
        properties: {
          'price': 9.99, // double
          'qty': 3, // int
          'vip': true, // bool
          'tags': ['a', 'b'], // List
          'ext': {'coupon': 'X1'}, // 嵌套 Map
          'note': null, // null
        },
      ),
    );

    expect(seq, 1);
    expect(received!['name'], 'purchase');
    final props = received!['properties'] as Map<Object?, Object?>;
    expect(props['price'], 9.99);
    expect(props['qty'], 3);
    expect(props['vip'], true);
    expect(props['tags'], ['a', 'b']);
    expect((props['ext'] as Map)['coupon'], 'X1');
    expect(props['note'], isNull);
  });

  test('拉取事件：原生 List<Map> 收窄成 List<AnalyticsEvent>', () async {
    mockNative((call) async {
      expect(call.method, 'fetchLoggedEvents');
      return [
        {
          'name': 'e1',
          'properties': {'k': 1},
        },
        {'name': 'e2', 'properties': <String, Object?>{}},
      ];
    });
    final events = await AnalyticsBridge.fetchLoggedEvents();
    expect(events.length, 2);
    expect(events[0].name, 'e1');
    expect(events[0].properties['k'], 1);
    expect(events[1].name, 'e2');
    expect(events[1].properties, isEmpty);
  });

  test('二进制：Uint8List 零拷贝传给原生，收到字节数', () async {
    mockNative((call) async {
      expect(call.method, 'uploadRawLog');
      // 原生侧拿到的就是字节（iOS 侧是 FlutterStandardTypedData，
      // 在 Dart mock 里表现为 Uint8List）。
      final data = call.arguments as Uint8List;
      return data.length;
    });
    final n = await AnalyticsBridge.uploadRawLog(
      Uint8List.fromList([1, 2, 3, 4, 5]),
    );
    expect(n, 5);
  });

  test('类型坑：原生返回 double 却用 <int> 接 → 运行时 TypeError', () async {
    // 本课高光：StandardMessageCodec 不做隐式数字转换。
    // 约定 int 就必须回 int，回 double 会在 Dart 侧 as int 时炸。
    mockNative((call) async => 3.0); // 原生"手滑"回了 double
    await expectLater(
      AnalyticsBridge.logEvent(const AnalyticsEvent(name: 'x')),
      throwsA(isA<TypeError>()),
    );
  });

  test('课后练习·批量上报：List<AnalyticsEvent> 作为顶层参数传给原生', () async {
    List<Object?>? received;
    mockNative((call) async {
      expect(call.method, 'logBatch');
      // 顶层参数这次是 List（对比 logEvent 是 Map）——codec 顶层就支持 List。
      received = call.arguments as List<Object?>;
      return 3; // 原生回 buffer 累加后的新总数
    });

    final total = await AnalyticsBridge.logBatch(const [
      AnalyticsEvent(name: 'a'),
      AnalyticsEvent(name: 'b'),
      AnalyticsEvent(name: 'c'),
    ]);

    expect(total, 3);
    expect(received!.length, 3);
    expect((received![0] as Map)['name'], 'a');
    expect((received![2] as Map)['name'], 'c');
  });

  testWidgets('L2 页面：上报事件后展示原生回的序号', (tester) async {
    mockNative((call) async {
      if (call.method == 'logEvent') return 1;
      return null;
    });
    await tester.pumpWidget(const MaterialApp(home: L2AnalyticsPage()));
    await tester.tap(find.text('上报一条埋点'));
    await tester.pumpAndSettle();
    // 断言用"回执序号"——它只出现在状态文案里，避开按钮"拉取已上报事件"的干扰。
    expect(find.textContaining('回执序号：1'), findsOneWidget);
  });

  testWidgets('L2 页面：拉取事件列表展示已上报事件', (tester) async {
    mockNative((call) async {
      if (call.method == 'fetchLoggedEvents') {
        return [
          {
            'name': 'purchase',
            'properties': {'price': 9.99},
          },
        ];
      }
      return null;
    });
    await tester.pumpWidget(const MaterialApp(home: L2AnalyticsPage()));
    await tester.tap(find.text('拉取已上报事件'));
    await tester.pumpAndSettle();
    expect(find.textContaining('purchase'), findsOneWidget);
  });
}
