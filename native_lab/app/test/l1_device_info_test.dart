import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_lab/lessons/l1/device_info_bridge.dart';
import 'package:native_lab/lessons/l1/l1_device_info_page.dart';

void main() {
  // channel 通信要走 binary messenger，测试环境得先把 binding 立起来。
  // iOS 类比：跑 XCTest 前得有个宿主 App 环境，一个意思。
  TestWidgetsFlutterBinding.ensureInitialized();

  // 小工具：把"假装自己是原生侧"的 handler 挂到我们的 channel 上。
  void mockNative(Future<Object?>? Function(MethodCall call)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceInfoBridge.channel, handler);
  }

  tearDown(() => mockNative(null)); // 每条测试后拆掉 mock，互不污染

  test('getDeviceInfo：成功解析原生返回的 Map', () async {
    mockNative((call) async {
      expect(call.method, 'getDeviceInfo');
      return {
        'model': 'iPhone',
        'systemName': 'iOS',
        'systemVersion': '19.0',
        'appVersion': '1.0.0',
      };
    });
    final info = await DeviceInfoBridge.fetchDeviceInfo();
    expect(info.model, 'iPhone');
    expect(info.systemName, 'iOS');
    expect(info.appVersion, '1.0.0');
  });

  test('getSystemUpTime: 成功解析系统开机时长秒数', () async {
    mockNative((call) async {
      expect(call.method, 'getSystemUpTime');
      return 12345.0;
    });

    final time = await DeviceInfoBridge.fetchUptime();
    expect(time, 12345.0);
  });

  test('原生 result.error 在 Dart 侧变成 PlatformException', () async {
    mockNative((call) async {
      throw PlatformException(code: 'UNAVAILABLE', message: '模拟器没有电池');
    });
    await expectLater(
      DeviceInfoBridge.fetchBatteryLevel(),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'UNAVAILABLE'),
      ),
    );
  });

  test('原生侧没注册 handler 时抛 MissingPluginException', () async {
    // 故意不挂 mock == 原生侧没人认领这条 channel（热重启后忘注册就是这景象）
    await expectLater(
      DeviceInfoBridge.fetchBatteryLevel(),
      throwsA(isA<MissingPluginException>()),
    );
  });

  testWidgets('L1 页面：点按钮展示设备信息', (tester) async {
    mockNative(
      (call) async => {
        'model': 'iPhone',
        'systemName': 'iOS',
        'systemVersion': '19.0',
        'appVersion': '1.0.0',
      },
    );
    await tester.pumpWidget(const MaterialApp(home: L1DeviceInfoPage()));
    await tester.tap(find.text('获取设备信息'));
    await tester.pumpAndSettle();
    expect(find.text('iPhone'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
  });

  testWidgets('L1 页面：原生报错时展示错误条', (tester) async {
    mockNative((call) async {
      throw PlatformException(code: 'UNAVAILABLE', message: '模拟器没有电池');
    });
    await tester.pumpWidget(const MaterialApp(home: L1DeviceInfoPage()));
    await tester.tap(find.text('获取电池电量'));
    await tester.pumpAndSettle();
    expect(find.textContaining('UNAVAILABLE'), findsOneWidget);
  });
}
