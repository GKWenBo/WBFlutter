import 'package:flutter/material.dart';

import 'network_bridge.dart';
import 'network_status.dart';

/// L3 入口页：网络状态推流的演示台。
/// 用 StreamBuilder 订阅原生推来的状态流，网络一变 banner 就实时翻——
/// 这就是 EventChannel 相对 MethodChannel 的价值：变了就推，不用轮询。
///
/// 教学点：StreamBuilder 替你托管了订阅的两件事——
///   挂载时 listen（触发原生 onListen 开始监听），
///   dispose 时 cancel（触发原生 onCancel 拆监听）。
/// 所以这里用 StatelessWidget 就够，不必手写 initState/dispose 管订阅。
class L3NetworkPage extends StatelessWidget {
  const L3NetworkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('L3 网络状态推流')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<NetworkInfo>(
          stream: NetworkBridge.statusStream(),
          builder: (context, snapshot) {
            // 原生推了 error 事件（如监听启动失败）→ 流里是 error。
            if (snapshot.hasError) {
              return Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('网络监听出错：${snapshot.error}'),
                ),
              );
            }
            // 还没等到第一条事件（原生刚 onListen，尚未推）。
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final info = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusBanner(info: info),
                const SizedBox(height: 16),
                const Text('试试关掉 Mac 的 Wi-Fi，看这里实时翻成"无网络连接"。'),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 状态横幅：不同状态给不同底色，一眼可辨。
/// L3 课后练习后，除了状态还展示信号强度（level 来自原生推的 Map）。
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.info});

  final NetworkInfo info;

  NetworkStatus get status => info.status;

  Color get _color => switch (status) {
    NetworkStatus.wifi => Colors.green,
    NetworkStatus.cellular => Colors.orange,
    NetworkStatus.none => Colors.red,
    NetworkStatus.unknown => Colors.grey,
  };

  IconData get _icon => switch (status) {
    NetworkStatus.wifi => Icons.wifi,
    NetworkStatus.cellular => Icons.signal_cellular_alt,
    NetworkStatus.none => Icons.wifi_off,
    NetworkStatus.unknown => Icons.help_outline,
  };

  @override
  Widget build(BuildContext context) {
    // 无网络时没有"信号强度"可言，隐藏副标题与信号格。
    final hasSignal = status != NetworkStatus.none;
    return Card(
      color: _color.withValues(alpha: 0.15),
      child: ListTile(
        leading: Icon(_icon, color: _color, size: 32),
        title: Text(
          status.label,
          style: TextStyle(color: _color, fontWeight: FontWeight.bold),
        ),
        subtitle: hasSignal ? Text('信号强度：${info.level} / 3') : null,
        trailing: hasSignal
            ? _SignalBars(level: info.level, color: _color)
            : null,
      ),
    );
  }
}

/// 信号格：把 level(0–3) 画成三根高矮不一的柱子，亮起前 level 根。
/// 纯 UI 小组件——练手用 Container + BoxDecoration 拼原子图形（iOS 里类似
/// 手撸 CALayer/UIView，不必上图片资源）。
class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.level, required this.color});

  final int level; // 0–3
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final on = i < level;
        return Container(
          width: 6,
          height: 8.0 + i * 7, // 从矮到高
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: on ? color : color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
