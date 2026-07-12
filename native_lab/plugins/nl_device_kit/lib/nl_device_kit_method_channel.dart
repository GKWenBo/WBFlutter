import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'nl_device_kit_platform_interface.dart';

/// An implementation of [NlDeviceKitPlatform] that uses method channels.
class MethodChannelNlDeviceKit extends NlDeviceKitPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('nl_device_kit');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
