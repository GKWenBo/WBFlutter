import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_lab/lessons/l4/l4_scan_page.dart';
import 'package:native_lab/lessons/l4/scan_bridge.dart';
import 'package:native_lab/lessons/l4/scan_outcome.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // 回到 MethodChannel 的 mock（对比 L3 的 setMockStreamHandler）：页面级混合
  // 本质还是"发一次请求、等一个结果"，只是原生那次响应是在用户扫完/取消后才回来。
  void mockScan(Future<Object?>? Function(MethodCall call)? handler) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      ScanBridge.channel,
      handler,
    );
  }

  tearDown(() => mockScan(null));

  test('扫到码：原生回字符串 → ScanSuccess(code)', () async {
    mockScan((call) async {
      expect(call.method, 'scan');
      return 'SKU-10086';
    });
    final outcome = await ScanBridge.scan();
    expect(outcome, isA<ScanSuccess>());
    expect((outcome as ScanSuccess).code, 'SKU-10086');
  });

  test('用户取消：原生回 null → ScanCancelled', () async {
    mockScan((call) async => null);
    expect(await ScanBridge.scan(), isA<ScanCancelled>());
  });

  test('权限被拒：原生抛 PERMISSION_DENIED → ScanPermissionDenied', () async {
    mockScan((call) async {
      throw PlatformException(code: 'PERMISSION_DENIED', message: '相机权限被拒');
    });
    expect(await ScanBridge.scan(), isA<ScanPermissionDenied>());
  });

  test('其它原生错误：原样抛出 PlatformException（如 ALREADY_SCANNING）', () async {
    mockScan((call) async {
      throw PlatformException(code: 'ALREADY_SCANNING', message: '已在扫码中');
    });
    expect(ScanBridge.scan(), throwsA(isA<PlatformException>()));
  });

  test('课后练习：hint 入参随 scan 透传给原生（打开原生页时携带参数）', () async {
    Object? received;
    mockScan((call) async {
      received = call.arguments; // 原生侧拿到的入参
      return 'SKU-1';
    });
    await ScanBridge.scan(hint: '请对准商品条码');
    expect(received, isA<Map>());
    expect((received! as Map)['hint'], '请对准商品条码');
  });

  test('课后练习：不传 hint 时 arguments 里 hint 为 null', () async {
    Object? received;
    mockScan((call) async {
      received = call.arguments;
      return null;
    });
    await ScanBridge.scan();
    expect((received! as Map)['hint'], isNull);
  });

  testWidgets('L4 页面：扫到码后展示 code', (tester) async {
    mockScan((call) async => 'SKU-10086');
    await tester.pumpWidget(const MaterialApp(home: L4ScanPage()));
    await tester.tap(find.text('扫码'));
    await tester.pumpAndSettle(); // 等 await scan() 完成 + setState 重建
    expect(find.textContaining('SKU-10086'), findsOneWidget);
  });

  testWidgets('L4 页面：权限被拒展示去设置提示', (tester) async {
    mockScan((call) async {
      throw PlatformException(code: 'PERMISSION_DENIED', message: '相机权限被拒');
    });
    await tester.pumpWidget(const MaterialApp(home: L4ScanPage()));
    await tester.tap(find.text('扫码'));
    await tester.pumpAndSettle();
    expect(find.textContaining('相机权限'), findsOneWidget);
  });
}
