import 'dart:typed_data';

import 'src/ffi_sign_binding.dart';
import 'src/nl_sign_binding.dart';

export 'src/ffi_sign_binding.dart' show FfiSignBinding;
export 'src/nl_sign_binding.dart'
    show NlSignBinding, NlSignErrorCode, NlSignException;

/// 门面：App 页面只依赖这一层，不直接碰 `dart:ffi`。
///
/// 构造时可注入 [NlSignBinding]：生产用默认的 [FfiSignBinding]，
/// widget 测试注入 fake（FFI 没有 channel 可 mock，这是唯一的测试接缝）。
final class NlSignKit {
  NlSignKit({NlSignBinding? binding}) : _binding = binding ?? FfiSignBinding();

  final NlSignBinding _binding;

  /// 原生 SDK 版本，例如 `1.0.0`。
  String get version => _binding.version;

  /// 初始化 SDK。真实项目通常在 App 启动时调一次。
  void initialize({required String appKey, required String appSecret}) {
    _binding.initialize(appKey: appKey, appSecret: appSecret);
  }

  /// 教学演示：用 C 库内置 demo 密钥初始化，Dart 不接触 secret。
  void initializeDemo() => _binding.initializeDemo();

  /// 对 canonical payload 做 HMAC-SHA256，返回 64 位十六进制签名。
  String sign(String canonicalPayload) =>
      _binding.hmacSha256Hex(canonicalPayload);

  /// 设备指纹（16 位十六进制）。
  String fingerprint(String seed) => _binding.fingerprintHex(seed);

  /// 二进制 CRC32。
  int crc32(Uint8List data) => _binding.crc32(data);
}
