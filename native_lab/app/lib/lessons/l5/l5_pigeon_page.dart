import 'package:flutter/material.dart';

import 'device_info_pigeon_bridge.dart';
import 'messages.g.dart';

/// L5 入口页：设备信息桥的 Pigeon 版演示台。
/// 与 L1 展示的是【同样的设备信息】，但通道由 Pigeon 生成——对照"手写 channel vs 生成"。
///
/// 用 StatefulWidget（不是 L3 那样的 StatelessWidget）：因为要在 initState 建 bridge、
/// dispose 里 stopBatteryUpdates + 释放，还要 setState 存 getDeviceInfo 的结果。
class L5PigeonPage extends StatefulWidget {
  const L5PigeonPage({super.key});

  @override
  State<L5PigeonPage> createState() => _L5PigeonPageState();
}

class _L5PigeonPageState extends State<L5PigeonPage> {
  late final DeviceInfoPigeonBridge _bridge = DeviceInfoPigeonBridge();

  DeviceInfoData? _info; // getDeviceInfo 的结果（强类型，不是 Map）
  BatteryInfo? _batteryInfo;
  Object? _error;
  bool _watching = false; // 是否已开电量订阅

  @override
  void dispose() {
    if (_watching) {
      _bridge.stopBatteryUpdates();
    }
    _bridge.dispose();
    super.dispose();
  }

  Future<void> _readDeviceInfo() async {
    try {
      final info = await _bridge.getDeviceInfo();
      setState(() {
        _info = info;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  Future<void> _readBatteryInfo() async {
    try {
      final info = await _bridge.getBatteryInfo();
      setState(() {
        _batteryInfo = info;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  Future<void> _toggleWatch(bool on) async {
    if (on) {
      await _bridge.startBatteryUpdates();
    } else {
      await _bridge.stopBatteryUpdates();
    }
    setState(() => _watching = on);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('L5 Pigeon 类型安全')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '和 L1 是同一份设备信息，但这里 channel、编解码、数据类全由 Pigeon '
                '从契约文件生成——不再手写魔法字符串和 Map 拆装。',
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── 正向 HostApi：Flutter 调原生取设备信息 ──────────────
          FilledButton.icon(
            onPressed: _readDeviceInfo,
            icon: const Icon(Icons.phone_iphone),
            label: const Text('读取设备信息'),
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
            _DeviceInfoCard(info: _info!),

          const Divider(height: 40),

          FilledButton.icon(onPressed: _readBatteryInfo,  icon: const Icon(Icons.phone_iphone), label: const Text("读取一次电量")),
          if (_batteryInfo != null) 
            _BatteryCard(info: _batteryInfo!),

          const Divider(height: 40),

          // ── 反向 FlutterApi：原生推电量给 Flutter（对照 L3 EventChannel）──
          SwitchListTile(
            title: const Text('电量订阅（反向 FlutterApi）'),
            subtitle: const Text('原生主动回推电量变化，类型是生成的 BatteryInfo'),
            value: _watching,
            onChanged: _toggleWatch,
          ),
          if (_watching)
            StreamBuilder<BatteryInfo>(
              stream: _bridge.batteryStream,
              // 兜底：原生在 startBatteryUpdates 里立即推的第一条，可能早于本 StreamBuilder
              // 订阅而被广播流丢弃。用 bridge 缓存的 latestBattery 作初值，避免永远空白。
              initialData: _bridge.latestBattery,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('等待原生推来第一条电量事件…'),
                  );
                }
                return _BatteryCard(info: snapshot.data!);
              },
            ),
        ],
      ),
    );
  }
}

/// 设备信息卡：强类型字段直接点出来（对照 L1 的 map['model'] as String）。
class _DeviceInfoCard extends StatelessWidget {
  const _DeviceInfoCard({required this.info});

  final DeviceInfoData info;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _row('机型', info.model),
          _row('系统', '${info.systemName} ${info.systemVersion}'),
          _row('真机', info.isPhysicalDevice ? '是' : '否（模拟器）'),
          _row('电量', info.batteryLevel == null ? '未知' : '${info.batteryLevel}%'),
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

/// 电量卡：展示反向推来的 BatteryInfo（强类型，不用手拆 Map）。
class _BatteryCard extends StatelessWidget {
  const _BatteryCard({required this.info});

  final BatteryInfo info;

  @override
  Widget build(BuildContext context) {
    final unknown = info.level < 0;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: Icon(info.isCharging ? Icons.battery_charging_full : Icons.battery_std),
        title: Text(unknown ? '电量未知' : '电量 ${info.level}%'),
        subtitle: Text(info.isCharging ? '充电中' : '未充电'),
      ),
    );
  }
}
