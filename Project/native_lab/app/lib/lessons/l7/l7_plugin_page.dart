import 'package:flutter/material.dart';
import 'package:nl_device_kit/nl_device_kit.dart';

/// L7 入口页：用插件 nl_device_kit 取设备信息。
/// 对照 L1：L1 的桥散在 app 里（手写 channel + AppDelegate 手写注册）；
/// 这里同样的能力来自【独立插件】——app 只 import 一个包、调 NlDeviceKit()，
/// 原生注册由 GeneratedPluginRegistrant 自动完成。
class L7PluginPage extends StatefulWidget {
  const L7PluginPage({super.key});

  @override
  State<L7PluginPage> createState() => _L7PluginPageState();
}

class _L7PluginPageState extends State<L7PluginPage> {
  final _kit = NlDeviceKit();
  DeviceInfo? _info;
  int? _battery;
  double? _uptime;
  Object? _error;
  String? _modeName;

  Future<void> _load() async {
    try {
      final info = await _kit.getDeviceInfo();
      final battery = await _kit.getBatteryLevel();
      final uptime = await _kit.getUptime();
      final modeName = await _kit.getDeviceModelName();
      setState(() {
        _info = info;
        _battery = battery;
        _uptime = uptime;
        _modeName = modeName;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('L7 插件：nl_device_kit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '和 L1 是同一份设备信息，但这里来自【独立插件】：app 只 import nl_device_kit、'
                '调 NlDeviceKit()，原生端由 GeneratedPluginRegistrant 自动注册（对照 L1 的手写注册）。',
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.extension),
            label: const Text('用插件读取设备信息'),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('读取失败：$_error'),
              ),
            )
          else if (_info != null)
            Card(
              child: Column(
                children: [
                  _row('机型', _info!.model),
                  _row('系统', '${_info!.systemName} ${_info!.systemVersion}'),
                  _row('App 版本', _info!.appVersion),
                  _row('电量', _battery == null ? '未知' : '$_battery%'),
                  _row(
                    '开机时长',
                    _uptime == null ? '未知' : '${_uptime!.toStringAsFixed(0)}s',
                  ),
                  _row("机型型号", _modeName ?? "未知"),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => ListTile(
    dense: true,
    title: Text(k),
    trailing: Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
  );
}
