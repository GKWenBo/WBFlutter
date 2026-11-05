import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_lab/lessons/l10/l10_ffi_sign_page.dart';
import 'package:native_lab/lessons/l10/order_signature.dart';
import 'package:nl_sign_kit/nl_sign_kit.dart';

/// FFI 没有 BinaryMessenger 可 mock，测试接缝放在 [NlSignBinding]。
final class _FakeBinding implements NlSignBinding {
  int initializeCalls = 0;
  String? lastCanonical;
  bool failInitialize = false;

  @override
  String get version => '1.0.0-test';

  @override
  void initialize({required String appKey, required String appSecret}) {
    initializeDemo();
  }

  @override
  void initializeDemo() {
    initializeCalls++;
    if (failInitialize) {
      throw const NlSignException(
        NlSignErrorCode.unsupportedPlatform,
        '测试：当前平台不支持 FFI',
      );
    }
  }

  @override
  String hmacSha256Hex(String message) {
    lastCanonical = message;
    if (message.isEmpty) {
      throw const NlSignException(
        NlSignErrorCode.invalidArgument,
        'message 不能为空',
      );
    }
    return List.filled(64, 'a').join();
  }

  @override
  String fingerprintHex(String seed) => '0123456789abcdef';

  @override
  int crc32(Uint8List data) => dartCrc32(data);
}

void main() {
  test('canonical payload：query 排序 + percent 编码 + 固定分隔符', () {
    final canonical = buildOrderCanonicalPayload(
      method: 'POST',
      path: '/api/v1/order',
      timestampMs: 1700000000000,
      query: {'b': '2 3', 'a': '1'},
      body: '{"sku":"SKU-10086"}',
    );

    expect(
      canonical,
      'POST\n'
      '/api/v1/order\n'
      'a=1&b=2%203\n'
      '1700000000000\n'
      '{"sku":"SKU-10086"}',
    );
  });

  test('Dart 侧 CRC32 参考实现符合 IEEE 标准向量', () {
    final bytes = Uint8List.fromList('123456789'.codeUnits);
    expect(dartCrc32(bytes), 0xCBF43926);
    expect(dartCrc32(Uint8List(0)), 0);
  });

  testWidgets('L10 页面：初始化后展示版本，并能生成签名', (tester) async {
    final binding = _FakeBinding();
    await _pumpL10(tester, NlSignKit(binding: binding));

    expect(find.text('L10 FFI：直接调用 C 库'), findsOneWidget);
    expect(find.textContaining('1.0.0-test'), findsOneWidget);
    expect(binding.initializeCalls, 1);

    await tester.ensureVisible(find.byKey(const Key('l10-sign')));
    await tester.tap(find.byKey(const Key('l10-sign')));
    await tester.pumpAndSettle();

    final signature = tester.widget<SelectableText>(
      find.byKey(const Key('l10-signature')),
    );
    expect(signature.data, List.filled(64, 'a').join());
    expect(binding.lastCanonical, contains('/api/v1/order'));
    expect(binding.lastCanonical, contains('orderId=ORDER-20261103-001'));
  });

  testWidgets('L10 页面：设备指纹与 CRC 校验结果都能展示', (tester) async {
    final binding = _FakeBinding();
    await _pumpL10(tester, NlSignKit(binding: binding));

    await tester.ensureVisible(find.byKey(const Key('l10-fingerprint')));
    await tester.tap(find.byKey(const Key('l10-fingerprint')));
    await tester.pumpAndSettle();
    final fingerprint = tester.widget<SelectableText>(
      find.byKey(const Key('l10-fingerprint-value')),
    );
    expect(fingerprint.data, '0123456789abcdef');

    await tester.ensureVisible(find.byKey(const Key('l10-crc')));
    await tester.tap(find.byKey(const Key('l10-crc')));
    await tester.pumpAndSettle();
    expect(find.text('校验一致 ✓'), findsOneWidget);
  });

  testWidgets('L10 页面：空 payload 触发原生错误码 1002', (tester) async {
    final binding = _FakeBinding();
    await _pumpL10(tester, NlSignKit(binding: binding));

    await tester.ensureVisible(find.byKey(const Key('l10-error')));
    await tester.tap(find.byKey(const Key('l10-error')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('l10-error-card')), findsOneWidget);
    expect(find.textContaining('INVALID_ARGUMENT (1002)'), findsOneWidget);
  });

  testWidgets('L10 页面：平台不支持时展示初始化错误而不是红屏', (tester) async {
    final binding = _FakeBinding()..failInitialize = true;
    await _pumpL10(tester, NlSignKit(binding: binding));

    expect(find.text('SDK 初始化失败'), findsOneWidget);
    expect(find.textContaining('UNSUPPORTED_PLATFORM (1005)'), findsOneWidget);
  });
}

/// 默认测试视口只有 800x600，L10 页面很长；把视口调高，避免和
/// ListView 里 TextField 自带的 Scrollable 抢 `scrollUntilVisible`。
Future<void> _pumpL10(WidgetTester tester, NlSignKit kit) async {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: L10FfiSignPage(kit: kit)));
}
