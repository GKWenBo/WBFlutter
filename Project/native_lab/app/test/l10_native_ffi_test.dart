import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nl_sign_kit/nl_sign_kit.dart';

/// FFI 的“原生层测试”思路：在宿主机（macOS/Linux）用 clang 把 src/nl_sign_kit.c
/// 编成临时 dylib/so，再用真实的 [FfiSignBinding] 跑已知向量。
///
/// 为什么不在模拟器里测？模拟器验证的是“集成”，而这里验证的是 C 算法/错误码，
/// 宿主机跑得快、能在 CI 里挡回归，两者互补。
void main() {
  test('C 层已知向量：RFC 4231 HMAC-SHA256 / CRC32 / 错误码', () {
    if (!Platform.isMacOS && !Platform.isLinux) {
      markTestSkipped('宿主编译测试只支持 macOS/Linux');
      return;
    }

    final source = _findNativeSource();
    if (source == null) {
      markTestSkipped('找不到 plugins/nl_sign_kit/src/nl_sign_kit.c');
      return;
    }

    final tempDir = Directory.systemTemp.createTempSync('nl_sign_kit_test_');
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final extension = Platform.isMacOS ? 'dylib' : 'so';
    final libraryPath = '${tempDir.path}/libnl_sign_kit.$extension';
    final compiler =
        Platform.environment['CC'] ?? (Platform.isMacOS ? 'clang' : 'cc');

    ProcessResult compileResult;
    try {
      compileResult = Process.runSync(compiler, [
        '-std=c11',
        '-shared',
        '-fPIC',
        '-O2',
        '-I',
        source.parent.path,
        '-o',
        libraryPath,
        source.path,
      ]);
    } on ProcessException catch (e) {
      markTestSkipped('宿主机没有可用的 C 编译器：$e');
      return;
    }

    if (compileResult.exitCode != 0) {
      fail(
        '编译 C 源码失败（${compileResult.exitCode}）：\n'
        '${compileResult.stdout}\n${compileResult.stderr}',
      );
    }

    final binding = FfiSignBinding(library: DynamicLibrary.open(libraryPath));

    expect(binding.version, '1.0.0');

    // 1) 未初始化：错误码 1001，且 last_error 有可读描述。
    expect(
      () => binding.hmacSha256Hex('x'),
      throwsA(
        isA<NlSignException>()
            .having((e) => e.code, 'code', NlSignErrorCode.notInitialized)
            .having((e) => e.message, 'message', contains('未初始化')),
      ),
    );

    // 2) 用 RFC 4231 Test Case 2 的 key 初始化，验证 HMAC 实现。
    binding.initialize(appKey: 'app-key', appSecret: 'Jefe');
    expect(
      binding.hmacSha256Hex('what do ya want for nothing?'),
      '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
    );

    // 3) CRC32 标准向量。
    expect(
      binding.crc32(Uint8List.fromList('123456789'.codeUnits)),
      0xCBF43926,
    );
    expect(binding.crc32(Uint8List(0)), 0);

    // 4) 指纹是 16 位十六进制，且相同 seed 稳定。
    final fingerprint = binding.fingerprintHex('device-1');
    expect(fingerprint, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(binding.fingerprintHex('device-1'), fingerprint);

    // 5) 空 message → 1002；Dart 侧拿到的是统一异常，不是崩溃。
    expect(
      () => binding.hmacSha256Hex(''),
      throwsA(
        isA<NlSignException>()
            .having((e) => e.code, 'code', NlSignErrorCode.invalidArgument)
            .having((e) => e.message, 'message', contains('不能为空')),
      ),
    );

    // 6) 演示页用的 init_demo 也能调通：Dart 不传 secret，密钥在 C 侧。
    binding.initializeDemo();
    expect(binding.hmacSha256Hex('order'), matches(RegExp(r'^[0-9a-f]{64}$')));
  });
}

File? _findNativeSource() {
  // flutter test 的 cwd 通常是 app/，但也可能从仓库根跑；都兼容。
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    final candidates = [
      File('${dir.path}/plugins/nl_sign_kit/src/nl_sign_kit.c'),
      File('${dir.path}/../plugins/nl_sign_kit/src/nl_sign_kit.c'),
    ];
    for (final candidate in candidates) {
      if (candidate.existsSync()) {
        return candidate.absolute;
      }
    }
    if (dir.parent.path == dir.path) {
      break;
    }
    dir = dir.parent;
  }
  return null;
}
