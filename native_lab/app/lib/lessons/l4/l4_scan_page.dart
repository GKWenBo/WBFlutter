import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'scan_bridge.dart';
import 'scan_outcome.dart';

/// L4 入口页：页面级混合的演示台。
/// 点"扫码" → 原生 present 一个扫码页盖住整屏 → 用户扫完/取消 → 结果回到这里。
///
/// 教学点：
/// - 单页局部状态（有没有结果、是否扫码中），用 StatefulWidget + setState 就够，
///   不必上 Riverpod（延续教学约定：能简单跑通就别堆架构）。
/// - present 出去的那段时间，这个 Flutter 页仍在栈里、只是被原生页盖住；
///   `await ScanBridge.scan()` 一直挂起，直到原生页 dismiss 才带着结果返回。
class L4ScanPage extends StatefulWidget {
  const L4ScanPage({super.key});

  @override
  State<L4ScanPage> createState() => _L4ScanPageState();
}

class _L4ScanPageState extends State<L4ScanPage> {
  ScanOutcome? _outcome; // 最近一次扫码结果（null = 还没扫过）
  String? _error; // 非约定内的原生错误（如 ALREADY_SCANNING）
  bool _scanning = false; // 扫码进行中：禁用按钮防重复触发

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      // 带一个 hint 下去（L4 课后练习）：原生扫码页会把它显示成标题。
      final outcome = await ScanBridge.scan(hint: '请对准商品条码 / 优惠券码');
      if (mounted) setState(() => _outcome = outcome);
    } on PlatformException catch (e) {
      // 桥把 PERMISSION_DENIED 收成了 ScanPermissionDenied，能到这里的是其它错误。
      if (mounted) setState(() => _error = '扫码出错：${e.code}');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('L4 页面级混合 · 扫码')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _scanning ? null : _startScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('扫码'),
            ),
            const SizedBox(height: 20),
            _buildResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    if (_error != null) {
      return _card(Colors.red, Icons.error_outline, _error!);
    }
    final outcome = _outcome;
    if (outcome == null) {
      return const Text('点上面的「扫码」，会唤起一个原生扫码页（本机无相机，用模拟页代替采集）。');
    }
    // sealed + switch：漏了任一子类型编译期就报错（对标 Swift enum 的穷尽 switch）。
    return switch (outcome) {
      ScanSuccess(:final code) => _card(
        Colors.green,
        Icons.check_circle,
        '扫到：$code',
      ),
      ScanCancelled() => _card(Colors.grey, Icons.cancel, '已取消'),
      ScanPermissionDenied() => _card(
        Colors.orange,
        Icons.lock_outline,
        '相机权限被拒，请到 设置 > NativeLab 开启相机后重试。',
      ),
    };
  }

  Widget _card(Color color, IconData icon, String text) {
    return Card(
      color: color.withValues(alpha: 0.15),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
