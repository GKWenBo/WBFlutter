import 'package:flutter_test/flutter_test.dart';
import 'package:nl_device_kit/nl_device_kit.dart';
import 'package:nl_device_kit/nl_device_kit_method_channel.dart';
import 'package:nl_device_kit/nl_device_kit_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// mock 掉 platform interface（这层缝的测试价值）：不碰真 channel，验证公开 API 转发。
class _MockPlatform extends NlDeviceKitPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<DeviceInfo> getDeviceInfo() async => const DeviceInfo(
    model: 'iPhone',
    systemName: 'iOS',
    systemVersion: '18.0',
    appVersion: '1.0',
  );
  @override
  Future<int> getBatteryLevel() async => 88;
  @override
  Future<double> getUptime() async => 123.5;
  @override
  Future<String> getDeviceModelName() async => "iPhone16,2";
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NlDeviceKit 三方法经 platform interface 转发', () async {
    NlDeviceKitPlatform.instance = _MockPlatform();
    final kit = NlDeviceKit();
    expect((await kit.getDeviceInfo()).model, 'iPhone');
    expect(await kit.getBatteryLevel(), 88);
    expect(await kit.getUptime(), 123.5);
    expect(await kit.getDeviceModelName(), "iPhone16,2");
  });

  test('MethodChannel 实现：getDeviceInfo 把原生 Map 收成强类型', () async {
    final impl = MethodChannelNlDeviceKit();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(impl.methodChannel, (call) async {
          if (call.method == 'getDeviceInfo') {
            return <String, Object?>{
              'model': 'Pixel',
              'systemName': 'Android',
              'systemVersion': '14',
              'appVersion': '2.0',
            };
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(impl.methodChannel, null),
    );

    final info = await impl.getDeviceInfo();
    expect(info.systemName, 'Android');
    expect(info.model, 'Pixel');
  });
}
