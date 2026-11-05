import 'package:flutter/material.dart';

import 'catalog.dart';

void main() {
  runApp(const AnimationExampleApp());
}

class AnimationExampleApp extends StatelessWidget {
  const AnimationExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter 动画示例',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

/// 首页：按分类分组的 Demo 目录。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter 常用动画')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final category in demoCategories) ...[
            ListTile(
              leading: Icon(category.icon),
              title: Text(category.name, style: textTheme.titleMedium),
              subtitle: Text(category.description),
            ),
            for (final entry in category.entries)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(entry.title),
                  subtitle: Text(entry.subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: entry.builder),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
