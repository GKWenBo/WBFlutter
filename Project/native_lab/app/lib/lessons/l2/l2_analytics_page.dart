import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'analytics_bridge.dart';
import 'analytics_event.dart';

/// L2 入口页：埋点桥的演示台。
/// 三个按钮分别演示：复杂嵌套参数下行、复杂列表返回上行、二进制传输。
class L2AnalyticsPage extends StatefulWidget {
  const L2AnalyticsPage({super.key});

  @override
  State<L2AnalyticsPage> createState() => _L2AnalyticsPageState();
}

class _L2AnalyticsPageState extends State<L2AnalyticsPage> {
  String? _status; // 最近一次操作的结果文案
  String? _error;
  List<AnalyticsEvent> _events = const [];

  /// 构造一个属性五花八门的事件（把 codec 的类型系统全踩一遍）上报。
  Future<void> _logOne() async {
    try {
      final seq = await AnalyticsBridge.logEvent(
        const AnalyticsEvent(
          name: 'purchase',
          properties: {
            'price': 9.99, // double
            'qty': 3, // int
            'vip': true, // bool
            'tags': ['flutter', 'native'], // List
            'ext': {'coupon': 'X1'}, // 嵌套 Map
          },
        ),
      );
      if (!mounted) return;
      setState(() {
        _status = '已上报 purchase，原生回执序号：$seq';
        _error = null;
      });
    } on PlatformException catch (e) {
      _showError('原生返回错误：${e.code}｜${e.message}');
    } on MissingPluginException {
      _showError('原生侧没注册 analytics channel（去查 AppDelegate）');
    }
  }

  /// 把原生 buffer 里的事件全拉回来，验证复杂结构往返无损。
  Future<void> _fetchAll() async {
    try {
      final events = await AnalyticsBridge.fetchLoggedEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        _status = '拉回 ${events.length} 条已上报事件';
        _error = null;
      });
    } on PlatformException catch (e) {
      _showError('原生返回错误：${e.code}｜${e.message}');
    } on MissingPluginException {
      _showError('原生侧没注册 analytics channel（去查 AppDelegate）');
    }
  }

  /// 传一小段二进制，原生数它多少字节回来——演示 Uint8List 零拷贝。
  Future<void> _uploadBinary() async {
    try {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final n = await AnalyticsBridge.uploadRawLog(bytes);
      if (!mounted) return;
      setState(() {
        _status = '上传 ${bytes.length} 字节，原生收到：$n 字节';
        _error = null;
      });
    } on PlatformException catch (e) {
      _showError('原生返回错误：${e.code}｜${e.message}');
    } on MissingPluginException {
      _showError('原生侧没注册 analytics channel（去查 AppDelegate）');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _error = msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('L2 埋点桥')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton(onPressed: _logOne, child: const Text('上报一条埋点')),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _fetchAll,
            child: const Text('拉取已上报事件'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _uploadBinary,
            child: const Text('上传二进制日志'),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!),
              ),
            ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _status!,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          // 拉回来的事件列表：事件名 + 属性原样展示，验证嵌套结构无损。
          for (final e in _events)
            Card(
              child: ListTile(
                title: Text(e.name),
                subtitle: Text('${e.properties}'),
              ),
            ),
        ],
      ),
    );
  }
}
