import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_lab/lessons/l3/l3_network_page.dart';
import 'package:native_lab/lessons/l3/network_bridge.dart';
import 'package:native_lab/lessons/l3/network_status.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // EventChannel 的 mock：不同于 MethodChannel 的 setMockMethodCallHandler,
  // 流用 setMockStreamHandler + MockStreamHandler.inline，在 onListen 里往 sink 推事件。
  void mockStream(MockStreamHandler? handler) {
    binding.defaultBinaryMessenger.setMockStreamHandler(
      NetworkBridge.channel,
      handler,
    );
  }

  tearDown(() => mockStream(null));

  test('纯映射：字符串 → NetworkStatus 枚举，未知落 unknown', () {
    expect(NetworkStatus.fromRaw('wifi'), NetworkStatus.wifi);
    expect(NetworkStatus.fromRaw('cellular'), NetworkStatus.cellular);
    expect(NetworkStatus.fromRaw('none'), NetworkStatus.none);
    expect(NetworkStatus.fromRaw('foobar'), NetworkStatus.unknown);
    expect(NetworkStatus.fromRaw(null), NetworkStatus.unknown);
  });

  test('纯映射：Map → NetworkInfo，缺字段/未知值都兜底', () {
    expect(
      NetworkInfo.fromMap({'type': 'wifi', 'level': 3}),
      const NetworkInfo(status: NetworkStatus.wifi, level: 3),
    );
    expect(
      NetworkInfo.fromMap({'type': 'none', 'level': 0}),
      const NetworkInfo(status: NetworkStatus.none, level: 0),
    );
    // 兜底：null map → unknown/0
    expect(
      NetworkInfo.fromMap(null),
      const NetworkInfo(status: NetworkStatus.unknown, level: 0),
    );
    // 兜底：缺 level → 0
    expect(NetworkInfo.fromMap({'type': 'wifi'}).level, 0);
    // 兜底：未知 type → unknown
    expect(
      NetworkInfo.fromMap({'type': 'foobar', 'level': 1}).status,
      NetworkStatus.unknown,
    );
    // level 是 double 也要能收（L2 的 int/double 坑，num.toInt 兜住）
    expect(NetworkInfo.fromMap({'type': 'wifi', 'level': 2.0}).level, 2);
  });

  test('状态流：原生推的 Map 序列被映射成 NetworkInfo 序列', () async {
    mockStream(
      MockStreamHandler.inline(
        onListen: (args, events) {
          // 原生"持续推"的模拟：连推三条再结束。
          events.success({'type': 'wifi', 'level': 3});
          events.success({'type': 'cellular', 'level': 2});
          events.success({'type': 'none', 'level': 0});
          events.endOfStream();
        },
      ),
    );

    final infos = await NetworkBridge.statusStream().toList();
    expect(infos, const [
      NetworkInfo(status: NetworkStatus.wifi, level: 3),
      NetworkInfo(status: NetworkStatus.cellular, level: 2),
      NetworkInfo(status: NetworkStatus.none, level: 0),
    ]);
  });

  test('课后练习：单个 Map 事件 → NetworkInfo（status==wifi && level==3）', () async {
    mockStream(
      MockStreamHandler.inline(
        onListen: (args, events) => events.success({'type': 'wifi', 'level': 3}),
      ),
    );

    final info = await NetworkBridge.statusStream().first;
    expect(info.status, NetworkStatus.wifi);
    expect(info.level, 3);
  });

  test('原生 error 事件在 Dart 流里表现为 PlatformException', () async {
    mockStream(
      MockStreamHandler.inline(
        onListen: (args, events) {
          events.error(code: 'MONITOR_FAILED', message: '网络监听启动失败');
        },
      ),
    );

    expect(
      NetworkBridge.statusStream(),
      emitsError(
        isA<PlatformException>().having((e) => e.code, 'code', 'MONITOR_FAILED'),
      ),
    );
  });

  testWidgets('L3 页面：StreamBuilder 随原生推送更新状态，并显示信号强度', (tester) async {
    mockStream(
      MockStreamHandler.inline(
        onListen: (args, events) => events.success({'type': 'wifi', 'level': 3}),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: L3NetworkPage()));
    await tester.pump(); // 让 stream 首个事件到达并重建
    expect(find.text('Wi-Fi 已连接'), findsOneWidget);
    expect(find.text('信号强度：3 / 3'), findsOneWidget);
  });

  testWidgets('L3 页面：断网时展示无网络文案，且不显示信号强度', (tester) async {
    mockStream(
      MockStreamHandler.inline(
        onListen: (args, events) => events.success({'type': 'none', 'level': 0}),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: L3NetworkPage()));
    await tester.pump();
    expect(find.text('无网络连接'), findsOneWidget);
    expect(find.textContaining('信号强度'), findsNothing);
  });
}
