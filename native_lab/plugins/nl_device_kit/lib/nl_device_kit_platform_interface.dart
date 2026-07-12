import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'nl_device_kit_method_channel.dart';

abstract class NlDeviceKitPlatform extends PlatformInterface {
  /// Constructs a NlDeviceKitPlatform.
  NlDeviceKitPlatform() : super(token: _token);

  static final Object _token = Object();

  static NlDeviceKitPlatform _instance = MethodChannelNlDeviceKit();

  /// The default instance of [NlDeviceKitPlatform] to use.
  ///
  /// Defaults to [MethodChannelNlDeviceKit].
  static NlDeviceKitPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NlDeviceKitPlatform] when
  /// they register themselves.
  static set instance(NlDeviceKitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
