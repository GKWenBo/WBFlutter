import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nl_sign_kit/nl_sign_kit.dart';

import 'order_signature.dart';

/// L10 入口页：FFI 版签名 SDK 的演示台。
///
/// 和前面九课最大的不同：这里没有 MethodChannel、没有 EventChannel，
/// Dart 直接按 C ABI 调原生函数（同步、无编解码）。
class L10FfiSignPage extends StatefulWidget {
  const L10FfiSignPage({super.key, this.kit});

  /// 测试注入点：生产不传，页面自己 new [NlSignKit]（底层 FfiSignBinding）。
  final NlSignKit? kit;

  @override
  State<L10FfiSignPage> createState() => _L10FfiSignPageState();
}

class _L10FfiSignPageState extends State<L10FfiSignPage> {
  late final NlSignKit _kit;
  final _orderIdController = TextEditingController(text: 'ORDER-20261103-001');
  final _amountController = TextEditingController(text: '199.00');

  bool _ready = false;
  String? _version;
  Object? _error;

  String? _canonical;
  String? _signature;
  int? _signMicros;

  String? _fingerprintSeed;
  String? _fingerprint;

  int? _nativeCrc;
  int? _dartCrc;
  int _nativeCrcMicros = 0;
  int _dartCrcMicros = 0;

  @override
  void initState() {
    super.initState();
    _kit = widget.kit ?? NlSignKit();
    // FFI 初始化是同步的：拿不到库/符号会抛 NlSignException，
    // 在 initState 里先兜住，避免第一帧就红屏。
    try {
      // 演示页不把 secret 写进 Dart：C 库内置一份 demo 密钥。
      // 真实项目应由原生安全存储（Keychain/Keystore）或服务端下发后注入。
      _kit.initializeDemo();
      _version = _kit.version;
      _ready = true;
    } on NlSignException catch (e) {
      _error = e;
    }
  }

  @override
  void dispose() {
    _orderIdController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _signOrder() {
    final canonical = buildOrderCanonicalPayload(
      method: 'POST',
      path: '/api/v1/order',
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      query: {
        'orderId': _orderIdController.text.trim(),
        'amount': _amountController.text.trim(),
        'channel': 'flutter',
      },
      body: '{"sku":"SKU-10086","qty":1}',
    );

    final watch = Stopwatch()..start();
    try {
      final signature = _kit.sign(canonical);
      watch.stop();
      setState(() {
        _canonical = canonical;
        _signature = signature;
        _signMicros = watch.elapsedMicroseconds;
        _error = null;
      });
    } on NlSignException catch (e) {
      watch.stop();
      setState(() => _error = e);
    }
  }

  void _makeFingerprint() {
    final seed =
        '${_orderIdController.text.trim()}|${defaultTargetPlatform.name}';
    try {
      final fingerprint = _kit.fingerprint(seed);
      setState(() {
        _fingerprintSeed = seed;
        _fingerprint = fingerprint;
        _error = null;
      });
    } on NlSignException catch (e) {
      setState(() => _error = e);
    }
  }

  void _runCrc() {
    // 2 MiB 的确定性数据：足够体现 native 与 Dart 的性能差，
    // 又不会让单帧超 16ms（再大就该丢进 Isolate.run 了）。
    final data = Uint8List(2 * 1024 * 1024);
    for (var i = 0; i < data.length; i++) {
      data[i] = i & 0xFF;
    }

    final nativeWatch = Stopwatch()..start();
    try {
      final nativeValue = _kit.crc32(data);
      nativeWatch.stop();

      final dartWatch = Stopwatch()..start();
      final dartValue = dartCrc32(data);
      dartWatch.stop();

      setState(() {
        _nativeCrc = nativeValue;
        _dartCrc = dartValue;
        _nativeCrcMicros = nativeWatch.elapsedMicroseconds;
        _dartCrcMicros = dartWatch.elapsedMicroseconds;
        _error = null;
      });
    } on NlSignException catch (e) {
      nativeWatch.stop();
      setState(() => _error = e);
    }
  }

  void _signEmptyPayload() {
    try {
      final signature = _kit.sign('');
      setState(() => _error = '空 payload 居然签成功了：$signature（预期是 1002）');
    } on NlSignException catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('L10 FFI：直接调用 C 库')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '本课把安全团队的 C 签名 SDK 通过 dart:ffi 直接接进 Flutter：'
                '没有 MethodChannel、没有编解码，调用按 C ABI 同步执行。'
                '下方签名/指纹/CRC 全部由同一份 src/nl_sign_kit.c 计算，'
                'Android 走 .so，iOS 走静态链接。',
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusCard(context),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _buildErrorCard(context),
          ],
          const SizedBox(height: 16),
          _buildSignCard(context),
          const SizedBox(height: 16),
          _buildFingerprintCard(context),
          const SizedBox(height: 16),
          _buildCrcCard(context),
          const SizedBox(height: 16),
          _buildErrorDemoCard(context),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              _ready ? Icons.check_circle : Icons.error_outline,
              color: _ready ? Colors.green : theme.colorScheme.error,
            ),
            title: Text(_ready ? 'SDK 已初始化' : 'SDK 初始化失败'),
            subtitle: Text(
              '版本：${_version ?? '未知'}\n'
              '运行端：${defaultTargetPlatform.name}',
            ),
            isThreeLine: true,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('l10-error-card'),
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '错误：${_describeError(_error!)}',
          style: TextStyle(color: theme.colorScheme.onErrorContainer),
        ),
      ),
    );
  }

  Widget _buildSignCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. 下单签名（HMAC-SHA256）', style: _titleStyle(context)),
            const SizedBox(height: 8),
            const Text(
              'Flutter 只负责拼 canonical payload；密钥和算法都在 C 侧，Dart 拿不到 secret。',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('l10-order-id'),
              controller: _orderIdController,
              decoration: const InputDecoration(labelText: 'orderId'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('l10-amount'),
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'amount'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('l10-sign'),
              onPressed: _ready ? _signOrder : null,
              icon: const Icon(Icons.fingerprint),
              label: const Text('生成下单签名'),
            ),
            if (_signature != null) ...[
              const SizedBox(height: 12),
              Text('canonical payload（服务端必须按同样规则拼）'),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _canonical!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              Text('签名（64 位十六进制）'),
              const SizedBox(height: 4),
              SelectableText(
                _signature!,
                key: const Key('l10-signature'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '原生耗时：${_formatMicros(_signMicros ?? 0)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFingerprintCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('2. 设备指纹（uint64 → 16 位 hex）', style: _titleStyle(context)),
            const SizedBox(height: 8),
            const Text('演示 Pointer<Uint8> 输出缓冲区和 int64/uint64 的 FFI 类型。'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('l10-fingerprint'),
              onPressed: _ready ? _makeFingerprint : null,
              icon: const Icon(Icons.devices),
              label: const Text('生成设备指纹'),
            ),
            if (_fingerprint != null) ...[
              const SizedBox(height: 12),
              Text('seed：${_fingerprintSeed ?? ''}'),
              const SizedBox(height: 4),
              SelectableText(
                _fingerprint!,
                key: const Key('l10-fingerprint-value'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCrcCard(BuildContext context) {
    final nativeHex = _nativeCrc?.toRadixString(16).padLeft(8, '0') ?? '-';
    final dartHex = _dartCrc?.toRadixString(16).padLeft(8, '0') ?? '-';
    final match = _nativeCrc != null && _nativeCrc == _dartCrc;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('3. 2 MiB 缓存校验（CRC32）', style: _titleStyle(context)),
            const SizedBox(height: 8),
            const Text(
              '同一份数据，原生 C 与 Dart 各算一次：既验证结果一致，'
              '也直观看到 FFI 为什么要用在耗时计算上。',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('l10-crc'),
              onPressed: _ready ? _runCrc : null,
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('计算 2 MiB 缓存 CRC32'),
            ),
            if (_nativeCrc != null) ...[
              const SizedBox(height: 12),
              _kv('原生 CRC32', '0x$nativeHex'),
              _kv('Dart CRC32', '0x$dartHex'),
              _kv('原生耗时', _formatMicros(_nativeCrcMicros)),
              _kv('Dart 耗时', _formatMicros(_dartCrcMicros)),
              const SizedBox(height: 4),
              Text(
                match ? '校验一致 ✓' : '校验不一致 ✗',
                key: const Key('l10-crc-match'),
                style: TextStyle(
                  color: match
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorDemoCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('4. 错误码映射', style: _titleStyle(context)),
            const SizedBox(height: 8),
            const Text(
              'C 只返回 int32 错误码，Dart 侧统一转成 NlSignException；'
              '空 canonical 会被原生拒绝（1002）。',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('l10-error'),
              onPressed: _signEmptyPayload,
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('用空 payload 签名（应失败）'),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle? _titleStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium;

  Widget _kv(String key, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(width: 100, child: Text(key)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  String _formatMicros(int micros) =>
      '${(micros / 1000).toStringAsFixed(2)} ms';

  String _describeError(Object error) {
    if (error is NlSignException) {
      return '${error.code.label} (${error.code.code})｜${error.message}';
    }
    return '$error';
  }
}
