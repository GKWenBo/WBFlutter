import 'package:flutter/material.dart';

import 'version_registry.dart';

/// 首页：同一个 MiniShop 的 N 种写法（对齐 native_lab 的课程列表页形态）。
class VersionListPage extends StatelessWidget {
  const VersionListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('StateLab · 同一个 MiniShop 的五种写法')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: versionRegistry.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final version = versionRegistry[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(version.id)),
              title: Text(version.title),
              subtitle: Text(version.subtitle),
              trailing: version.unlocked
                  ? const Icon(Icons.chevron_right)
                  : const Icon(Icons.lock_outline),
              onTap: () {
                if (version.unlocked) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: version.builder!),
                  );
                } else {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text('该版本在 ${version.unlockLesson} 解锁'),
                    ));
                }
              },
            ),
          );
        },
      ),
    );
  }
}
