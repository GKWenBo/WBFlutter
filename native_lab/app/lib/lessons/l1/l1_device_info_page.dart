import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'device_info.dart';
import 'device_info_bridge.dart';

/// L1 入口页：设备信息桥的演示台。
/// 企业场景里这些数据会静默上报；教学页面把它可视化。
class L1DeviceInfoPage extends StatefulWidget {
  const L1DeviceInfoPage({super.key});

  @override
  State<L1DeviceInfoPage> createState() => _L1DeviceInfoPageState();
}

class _L1DeviceInfoPageState extends State<L1DeviceInfoPage> {
  DeviceInfo? _info;
  int? _battery;
  String? _error;
  double? _time;

  Future<void> _loadDeviceInfo() async {
    // 教学点：只 catch 具体异常，不写宽 catch（WanShop M9 的老规矩）。
    try {
      final info = await DeviceInfoBridge.fetchDeviceInfo();
      if (!mounted) return; // await 之后碰 State 前先查 mounted（M10 老规矩）
      setState(() {
        _info = info;
        _error = null;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _error = '原生返回错误：${e.code}｜${e.message}');
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _error = '原生侧没注册这条 channel（去查 AppDelegate）');
    }
  }

  Future<void> _loadBattery() async {
    try {
      final battery = await DeviceInfoBridge.fetchBatteryLevel();
      if (!mounted) return;
      setState(() {
        _battery = battery;
        _error = null;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _error = '原生返回错误：${e.code}｜${e.message}');
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _error = '原生侧没注册这条 channel（去查 AppDelegate）');
    }
  }

  Future<void> _loadSystemUptime() async {
    try {
      final systemTime = await DeviceInfoBridge.fetchUptime();
      if (!mounted) return;
      setState(() {
        _time = systemTime;
        _error = null;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _error = '原生返回错误：${e.code}｜${e.message}');
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _error = '原生侧没注册这条 channel（去查 AppDelegate）');
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Scaffold(
      appBar: AppBar(title: const Text('L1 设备信息桥')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton(onPressed: _loadDeviceInfo, child: const Text('获取设备信息')),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _loadBattery,
            child: const Text('获取电池电量'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _loadSystemUptime,
            child: const Text('获取开机时长'),
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
          if (info != null) ...[
            ListTile(title: const Text('机型'), trailing: Text(info.model)),
            ListTile(title: const Text('系统'), trailing: Text(info.systemName)),
            ListTile(
              title: const Text('系统版本'),
              trailing: Text(info.systemVersion),
            ),
            ListTile(
              title: const Text('App 版本'),
              trailing: Text(info.appVersion),
            ),
          ],
          if (_battery != null)
            ListTile(title: const Text('电池电量'), trailing: Text('$_battery%')),

          if (_time != null)
            ListTile(title: const Text('系统开机时长'), trailing: Text('$_time')),
        ],
      ),
    );
  }
}
