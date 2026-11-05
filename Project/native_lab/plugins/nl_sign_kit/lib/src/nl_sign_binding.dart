import 'dart:typed_data';

/// C SDK 错误码的 Dart 映射。
///
/// 数值必须与 `src/nl_sign_kit.h` 里的 `NL_SIGN_KIT_ERR_*` 逐值一致；
/// 1005/1006 是 Dart 侧新增的（平台不支持 / 动态库加载失败），C 里没有。
enum NlSignErrorCode {
  notInitialized(1001, 'NOT_INITIALIZED'),
  invalidArgument(1002, 'INVALID_ARGUMENT'),
  bufferTooSmall(1003, 'BUFFER_TOO_SMALL'),
  internal(1004, 'INTERNAL'),
  unsupportedPlatform(1005, 'UNSUPPORTED_PLATFORM'),
  loadFailed(1006, 'LOAD_FAILED');

  const NlSignErrorCode(this.code, this.label);

  /// 与 C 头文件对应的整型错误码。
  final int code;

  /// 日志/页面展示用的稳定名称。
  final String label;

  static NlSignErrorCode fromNative(int code) => switch (code) {
    1001 => notInitialized,
    1002 => invalidArgument,
    1003 => bufferTooSmall,
    1004 => internal,
    _ => internal,
  };
}

/// FFI 层统一抛这个异常，页面只 catch 它。
///
/// iOS 类比：相当于把 C 的 `int32_t errno` + `strerror` 包成一个 Swift Error，
/// 调用方不用每次手动检查返回码。
class NlSignException implements Exception {
  const NlSignException(this.code, this.message);

  final NlSignErrorCode code;
  final String message;

  @override
  String toString() => 'NlSignException(${code.label}/${code.code}): $message';
}

/// FFI 绑定的抽象接口：页面/测试只依赖它，生产实现是 [FfiSignBinding]。
///
/// 这是 FFI 测试的关键接缝：channel 时代可以 mock BinaryMessenger，
/// FFI 没有 channel，只能在 Dart 边界注入 fake。
abstract interface class NlSignBinding {
  /// 原生库版本，例如 `1.0.0`。
  String get version;

  /// 初始化 SDK（把 app_key/app_secret 存进原生侧）。
  void initialize({required String appKey, required String appSecret});

  /// 教学演示：使用 C 库内置的 demo 密钥初始化，Dart 侧不接触 secret。
  void initializeDemo();

  /// HMAC-SHA256，返回 64 位小写十六进制。
  String hmacSha256Hex(String message);

  /// 设备指纹，返回 16 位小写十六进制。
  String fingerprintHex(String seed);

  /// 二进制 CRC32（IEEE 802.3）。
  int crc32(Uint8List data);
}
