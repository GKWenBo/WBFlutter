import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_module/host_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.wenbo.add_to_app/host');
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('Flutter → 原生：getUserToken / closePage 正确发出', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'getUserToken' ? 'TOKEN-123' : null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    expect(await HostBridge.instance.getUserToken(), 'TOKEN-123');
    await HostBridge.instance.closePage();
    expect(calls.map((c) => c.method).toList(), ['getUserToken', 'closePage']);
  });

  test('原生 → Flutter：getPageState 由页面注册的提供者应答', () async {
    HostBridge.instance.onHostQuery = () => '商品详情页（/detail）';
    // 模拟【原生打进来】：走真实 codec + 真实接收端（不是直接调 Dart 方法）。
    final reply = await messenger.handlePlatformMessage(
      'com.wenbo.add_to_app/host',
      codec.encodeMethodCall(const MethodCall('getPageState')),
      null,
    );
    expect(codec.decodeEnvelope(reply!), '商品详情页（/detail）');
  });
}
