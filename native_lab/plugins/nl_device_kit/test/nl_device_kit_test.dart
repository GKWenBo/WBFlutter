import 'package:flutter_test/flutter_test.dart';
import 'package:nl_device_kit/nl_device_kit.dart';
import 'package:nl_device_kit/nl_device_kit_platform_interface.dart';
import 'package:nl_device_kit/nl_device_kit_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNlDeviceKitPlatform
    with MockPlatformInterfaceMixin
    implements NlDeviceKitPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final NlDeviceKitPlatform initialPlatform = NlDeviceKitPlatform.instance;

  test('$MethodChannelNlDeviceKit is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNlDeviceKit>());
  });

  test('getPlatformVersion', () async {
    NlDeviceKit nlDeviceKitPlugin = NlDeviceKit();
    MockNlDeviceKitPlatform fakePlatform = MockNlDeviceKitPlatform();
    NlDeviceKitPlatform.instance = fakePlatform;

    expect(await nlDeviceKitPlugin.getPlatformVersion(), '42');
  });
}
