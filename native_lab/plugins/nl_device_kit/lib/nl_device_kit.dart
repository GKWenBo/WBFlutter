
import 'nl_device_kit_platform_interface.dart';

class NlDeviceKit {
  Future<String?> getPlatformVersion() {
    return NlDeviceKitPlatform.instance.getPlatformVersion();
  }
}
