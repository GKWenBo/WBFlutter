import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/app_info.dart';
import 'demo_registry.dart';

/// 课程目录首页。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 读取 appVersionProvider 并订阅：版本号变化时这里自动重建。
    final version = ref.watch(appVersionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riverpod Lab'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('v$version'),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: demos.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _DemoCard(demo: demos[index]),
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.demo});

  final DemoEntry demo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final implemented = demo.pageBuilder != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: implemented
            ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: demo.pageBuilder!),
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(demo.title, style: theme.textTheme.titleMedium),
                  ),
                  if (!implemented)
                    Text(
                      '待实现',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(demo.summary, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final concept in demo.concepts)
                    Chip(
                      label: Text(concept),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
