import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'nl_sign_binding.dart';

/// C 函数签名（native 侧）。
typedef _VersionNative = Pointer<Utf8> Function();
typedef _VersionDart = Pointer<Utf8> Function();

typedef _InitNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _InitDart = int Function(Pointer<Utf8>, Pointer<Utf8>);

typedef _InitDemoNative = Int32 Function();
typedef _InitDemoDart = int Function();

typedef _HmacNative = Int32 Function(Pointer<Utf8>, Pointer<Uint8>, Int32);
typedef _HmacDart = int Function(Pointer<Utf8>, Pointer<Uint8>, int);

typedef _FingerprintNative =
    Int32 Function(Pointer<Utf8>, Pointer<Uint8>, Int32);
typedef _FingerprintDart = int Function(Pointer<Utf8>, Pointer<Uint8>, int);

typedef _Crc32Native = Int32 Function(Pointer<Uint8>, Int32, Pointer<Uint32>);
typedef _Crc32Dart = int Function(Pointer<Uint8>, int, Pointer<Uint32>);

typedef _LastErrorNative = Pointer<Utf8> Function();
typedef _LastErrorDart = Pointer<Utf8> Function();

/// 64 个十六进制字符 + '\0'。
const int _hmacHexBufferSize = 65;

/// 16 个十六进制字符 + '\0'。
const int _fingerprintHexBufferSize = 17;

/// 真正的 dart:ffi 实现。
///
/// iOS 类比：`DynamicLibrary` 就是 dlopen 的句柄；`lookupFunction` 就是 dlsym。
/// 与 MethodChannel 最大的不同：调用是同步的，参数/返回值直接按 C ABI 走，
/// 没有编解码、没有 Platform 线程切换。
final class FfiSignBinding implements NlSignBinding {
  FfiSignBinding({DynamicLibrary? library}) : _providedLibrary = library;

  final DynamicLibrary? _providedLibrary;
  _FfiSymbols? _symbols;

  _FfiSymbols get _ffi =>
      _symbols ??= _FfiSymbols.load(_providedLibrary ?? _openLibrary());

  @override
  String get version => _ffi.version().toDartString();

  @override
  void initialize({required String appKey, required String appSecret}) {
    final keyPtr = appKey.toNativeUtf8();
    final secretPtr = appSecret.toNativeUtf8();
    try {
      final rc = _ffi.init(keyPtr, secretPtr);
      if (rc != 0) {
        _throwNative(rc);
      }
    } finally {
      malloc.free(keyPtr);
      malloc.free(secretPtr);
    }
  }

  @override
  void initializeDemo() {
    final rc = _ffi.initDemo();
    if (rc != 0) {
      _throwNative(rc);
    }
  }

  @override
  String hmacSha256Hex(String message) {
    final messagePtr = message.toNativeUtf8();
    final outPtr = calloc<Uint8>(_hmacHexBufferSize);
    try {
      final rc = _ffi.hmacSha256Hex(messagePtr, outPtr, _hmacHexBufferSize);
      if (rc != 0) {
        _throwNative(rc);
      }
      return outPtr.cast<Utf8>().toDartString();
    } finally {
      malloc.free(messagePtr);
      calloc.free(outPtr);
    }
  }

  @override
  String fingerprintHex(String seed) {
    final seedPtr = seed.toNativeUtf8();
    final outPtr = calloc<Uint8>(_fingerprintHexBufferSize);
    try {
      final rc = _ffi.fingerprintHex(
        seedPtr,
        outPtr,
        _fingerprintHexBufferSize,
      );
      if (rc != 0) {
        _throwNative(rc);
      }
      return outPtr.cast<Utf8>().toDartString();
    } finally {
      malloc.free(seedPtr);
      calloc.free(outPtr);
    }
  }

  @override
  int crc32(Uint8List data) {
    // C 侧长度是 int32_t：超过 2GB 必须分块，否则会悄悄截断。
    if (data.length > 0x7fffffff) {
      throw const NlSignException(
        NlSignErrorCode.invalidArgument,
        '单次 CRC 不能超过 2GB，请分块计算',
      );
    }
    if (data.isEmpty) {
      return 0; // CRC32 空数据的标准结果就是 0，不必进 native。
    }

    final dataPtr = calloc<Uint8>(data.length);
    final outPtr = calloc<Uint32>();
    try {
      // Dart 的 Uint8List 是托管的，不能直接取地址；先拷进 native 内存。
      dataPtr.asTypedList(data.length).setAll(0, data);
      final rc = _ffi.crc32(dataPtr, data.length, outPtr);
      if (rc != 0) {
        _throwNative(rc);
      }
      return outPtr.value;
    } finally {
      calloc.free(dataPtr);
      calloc.free(outPtr);
    }
  }

  Never _throwNative(int rc) {
    final errorPtr = _ffi.lastError();
    final message = errorPtr == nullptr
        ? '原生侧未提供错误描述'
        : errorPtr.toDartString();
    throw NlSignException(NlSignErrorCode.fromNative(rc), message);
  }

  static DynamicLibrary _openLibrary() {
    if (Platform.isAndroid) {
      // Android：Gradle/CMake 把 .so 打进 APK，dlopen 按文件名查找。
      try {
        return DynamicLibrary.open('libnl_sign_kit.so');
      } on ArgumentError catch (e) {
        throw NlSignException(
          NlSignErrorCode.loadFailed,
          '加载 libnl_sign_kit.so 失败：$e（确认 APK 的 lib/<abi>/ 里有该文件）',
        );
      }
    }

    if (Platform.isIOS) {
      // iOS：C 代码静态链接进 App，优先从当前进程找符号（等价 dlsym(RTLD_DEFAULT)）。
      Object? lastError;
      try {
        final process = DynamicLibrary.process();
        process.lookup('nl_sign_kit_version'); // 探活：符号在才算成功
        return process;
      } catch (e) {
        lastError = e;
      }

      // 兜底：如果团队改成了动态 framework，按常见的 framework 路径再找一次。
      const candidates = <String>[
        'nl_sign_kit.framework/nl_sign_kit',
        '@rpath/nl_sign_kit.framework/nl_sign_kit',
      ];
      for (final path in candidates) {
        try {
          final library = DynamicLibrary.open(path);
          library.lookup('nl_sign_kit_version');
          return library;
        } catch (e) {
          lastError = e;
        }
      }

      throw NlSignException(
        NlSignErrorCode.loadFailed,
        'iOS 上找不到 nl_sign_kit 符号：$lastError。'
        '检查 NlSignKitPlugin.register 是否调用了 nl_sign_kit_warmup()'
        '（静态链接裁剪是最常见原因）。',
      );
    }

    throw NlSignException(
      NlSignErrorCode.unsupportedPlatform,
      'L10 FFI 示例只支持 iOS/Android，当前平台是 ${Platform.operatingSystem}',
    );
  }
}

/// 一次性解析所有符号：少一个都直接报错，而不是等到调用时才崩。
final class _FfiSymbols {
  _FfiSymbols._(DynamicLibrary library)
    : version = library.lookupFunction<_VersionNative, _VersionDart>(
        'nl_sign_kit_version',
      ),
      init = library.lookupFunction<_InitNative, _InitDart>('nl_sign_kit_init'),
      initDemo = library.lookupFunction<_InitDemoNative, _InitDemoDart>(
        'nl_sign_kit_init_demo',
      ),
      hmacSha256Hex = library.lookupFunction<_HmacNative, _HmacDart>(
        'nl_sign_kit_hmac_sha256_hex',
      ),
      fingerprintHex = library
          .lookupFunction<_FingerprintNative, _FingerprintDart>(
            'nl_sign_kit_fingerprint_hex',
          ),
      crc32 = library.lookupFunction<_Crc32Native, _Crc32Dart>(
        'nl_sign_kit_crc32',
      ),
      lastError = library.lookupFunction<_LastErrorNative, _LastErrorDart>(
        'nl_sign_kit_last_error',
      );

  final _VersionDart version;
  final _InitDart init;
  final _InitDemoDart initDemo;
  final _HmacDart hmacSha256Hex;
  final _FingerprintDart fingerprintHex;
  final _Crc32Dart crc32;
  final _LastErrorDart lastError;

  static _FfiSymbols load(DynamicLibrary library) {
    try {
      return _FfiSymbols._(library);
    } on ArgumentError catch (e) {
      throw NlSignException(
        NlSignErrorCode.loadFailed,
        '动态库里缺少 nl_sign_kit_* 符号：$e',
      );
    }
  }
}
