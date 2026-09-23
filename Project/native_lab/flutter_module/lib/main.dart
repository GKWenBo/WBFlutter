import 'dart:ui';

import 'package:flutter/material.dart';

import 'host_bridge.dart';

/// add-to-app 模块的入口。
/// ★ 与 L0–L7 最大的心智差异：那边 Flutter 是整个 App（Flutter 当家，原生是配角）；
///   这里 Flutter 只是被原生 App "接进来"的一块内容——**原生才是宿主**。
///   所以：谁先启动、谁决定路由、谁负责关页面，全都反过来了。
void main() => runApp(const ModuleApp());

class ModuleApp extends StatelessWidget {
  const ModuleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 宿主用 setInitialRoute 指定要打开哪一页（L9 路由协调）。
    // 拿不到就回落到 '/'——防止宿主没设时白屏。
    final initial = PlatformDispatcher.instance.defaultRouteName;
    return MaterialApp(
      title: 'Flutter Module',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      // 宿主在引擎【跑起来之后】切页要靠它（见 host_bridge 的 setRoute）。
      navigatorKey: moduleNavigatorKey,
      initialRoute: initial.isEmpty ? '/' : initial,
      routes: {
        '/': (_) => const ModuleHomePage(),
        '/detail': (_) => const ModuleDetailPage(),
      },
      // 宿主传了未知路由时兜底，别让混合栈直接崩。
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => ModuleHomePage(unknownRoute: settings.name),
      ),
    );
  }
}

/// 模块首页：L8 用它验证"原生能打开一个 Flutter 页"。
class ModuleHomePage extends StatefulWidget {
  const ModuleHomePage({super.key, this.unknownRoute});

  /// 宿主传来的未知路由名（兜底展示用）。
  final String? unknownRoute;

  @override
  State<ModuleHomePage> createState() => _ModuleHomePageState();
}

class _ModuleHomePageState extends State<ModuleHomePage> {
  String? _token; // 向宿主要来的用户 token（Flutter → 原生）
  Object? _error;

  @override
  void initState() {
    super.initState();
    // L9：注册状态提供者，让【原生】能反过来问 Flutter 要当前页状态。
    HostBridge.instance.onHostQuery = () => '模块首页 / token=${_token ?? "未取"}';
  }

  Future<void> _fetchToken() async {
    try {
      final token = await HostBridge.instance.getUserToken();
      setState(() {
        _token = token;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter 模块首页'),
        // ★ 这里【没有】返回按钮——这个页面是被原生 present 出来的，
        //   在 Flutter 路由栈里它就是根页。要关掉它必须【喊原生】（见下方按钮）。
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '这一整屏是 Flutter 画的，但它跑在【原生 App】里。\n'
                '宿主是 WBiOSProject（SwiftUI），通过 CocoaPods 接入本模块。',
              ),
            ),
          ),
          if (widget.unknownRoute != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('（宿主传来未知路由：${widget.unknownRoute}，已兜底到首页）'),
            ),
          const SizedBox(height: 16),

          // ── Flutter → 原生：问宿主要数据 ──────────────────────
          FilledButton.icon(
            onPressed: _fetchToken,
            icon: const Icon(Icons.vpn_key),
            label: const Text('向宿主要用户 token'),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('要不到：$_error'),
              ),
            )
          else if (_token != null)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.check_circle),
                title: const Text('宿主给的 token'),
                subtitle: Text(_token!),
              ),
            ),

          const Divider(height: 40),

          // ── Flutter → 原生：请宿主关掉我 ──────────────────────
          OutlinedButton.icon(
            onPressed: HostBridge.instance.closePage,
            icon: const Icon(Icons.close),
            label: const Text('请宿主关闭这个 Flutter 页'),
          ),
        ],
      ),
    );
  }
}

/// 模块详情页：L9 用它验证"原生指定打开哪一页"（setInitialRoute('/detail')）。
class ModuleDetailPage extends StatefulWidget {
  const ModuleDetailPage({super.key});

  @override
  State<ModuleDetailPage> createState() => _ModuleDetailPageState();
}

class _ModuleDetailPageState extends State<ModuleDetailPage> {
  @override
  void initState() {
    super.initState();
    HostBridge.instance.onHostQuery = () => '商品详情页（/detail）';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter 模块 · 商品详情'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 64),
              const SizedBox(height: 16),
              const Text(
                '你现在看到的是 /detail 页。\n'
                '不是 Flutter 自己跳过来的——是【原生宿主】通过通道\n'
                'setRoute("/detail") 驱动 Navigator 跳过来的。\n\n'
                '★ 为什么不用 setInitialRoute？因为引擎是预热的、早就在跑了，\n'
                '那时 widget 树已按 initialRoute 建好，再设它不会有任何反应。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: HostBridge.instance.closePage,
                icon: const Icon(Icons.close),
                label: const Text('请宿主关闭'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
