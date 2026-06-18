import 'package:flutter/material.dart';

/// 首页（商品流）。
/// M1 会把这里做成真正的电商首页：搜索框 + Banner + 分类入口 + 商品网格。
/// 现在先用占位页，让 4-Tab 骨架先跑起来。
///
/// 没有内部状态 → StatelessWidget。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WanShop')),
      body: const Center(
        child: Text('首页 · 建设中', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
