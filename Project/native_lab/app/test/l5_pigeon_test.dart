import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_lab/lessons/l5/device_info_pigeon_bridge.dart';
import 'package:native_lab/lessons/l5/l5_pigeon_page.dart';
import 'package:native_lab/lessons/l5/messages.g.dart';

// pigeon 27 弃用了"生成 mock host"（dartHostTestHandler），官方改推
// 【直接 fake 生成的 Dart API】：继承生成的 DeviceInfoHostApi、覆写方法当假原生，
// 通过构造函数注入 bridge（依赖注入 + fake）。
// 对照 L1：那时手写 setMockMethodCallHandler + 手拼返回 Map；这里覆写强类型方法、
// 返回强类型对象——桩更贴近"真调用"，且 model/systemVersion 打错字编译就报。
class _FakeHost extends DeviceInfoHostApi {
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Future<DeviceInfoData> getDeviceInfo() async => DeviceInfoData(
        model: 'iPhone',
        systemName: 'iOS',
        systemVersion: '18.0',
        isPhysicalDevice: false,
        batteryLevel: 80,
      );

  @override
  Future<void> startBatteryUpdates() async => startCalls++;

  @override
  Future<void> stopBatteryUpdates() async => stopCalls++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getDeviceInfo：拿到强类型 DeviceInfoData（非 Map）', () async {
    final bridge = DeviceInfoPigeonBridge(hostApi: _FakeHost());
    final info = await bridge.getDeviceInfo();
    // 直接点字段，编译期就有类型——对照 L1 的 map['model'] as String（运行期才崩）。
    expect(info.model, 'iPhone');
    expect(info.systemVersion, '18.0');
    expect(info.batteryLevel, 80);
    bridge.dispose();
  });

  test('start/stopBatteryUpdates 转发到 host', () async {
    final fake = _FakeHost();
    final bridge = DeviceInfoPigeonBridge(hostApi: fake);
    await bridge.startBatteryUpdates();
    await bridge.stopBatteryUpdates();
    expect(fake.startCalls, 1);
    expect(fake.stopCalls, 1);
    bridge.dispose();
  });

  test('反向 FlutterApi：喂 BatteryInfo → batteryStream 吐出同一个对象', () async {
    final bridge = DeviceInfoPigeonBridge(hostApi: _FakeHost());
    // 直接调 Dart 接收端（bridge 实现了 DeviceEventFlutterApi），
    // 模拟"原生推了一个电量事件"，验证我们把它转成了 Stream（对照 L3 statusStream）。
    final future = bridge.batteryStream.first;
    bridge.onBatteryChanged(BatteryInfo(level: 42, isCharging: true));
    final got = await future;
    expect(got.level, 42);
    expect(got.isCharging, true);
    bridge.dispose();
  });

  testWidgets('L5 页面：读取设备信息展示 Pigeon 返回的 model', (tester) async {
    // 页面自己 new bridge()，无法注入 fake host；用 setMockMethodCallHandler 在
    // Pigeon 私有 channel 上顶替原生的 getDeviceInfo 回复（BasicMessageChannel，
    // 回复格式是 [返回值] 的 List）。这演示"Pigeon 底层仍是 channel"。
    const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.native_lab.DeviceInfoHostApi.getDeviceInfo',
      DeviceInfoHostApi.pigeonChannelCodec,
    );
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      channel,
      (Object? message) async => <Object?>[
        DeviceInfoData(
          model: 'iPhone',
          systemName: 'iOS',
          systemVersion: '18.0',
          isPhysicalDevice: false,
          batteryLevel: 80,
        ),
      ],
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler(channel, null));

    await tester.pumpWidget(const MaterialApp(home: L5PigeonPage()));
    await tester.tap(find.text('读取设备信息'));
    await tester.pumpAndSettle();
    expect(find.textContaining('iPhone'), findsOneWidget);
  });
}
