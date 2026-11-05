import 'package:flutter/widgets.dart';

/// 首页目录中的一项。
///
/// 每完成一课，把 [pageBuilder] 填上即可，首页入口会自动变为可点击。
/// [pageBuilder] 为 null 表示这一课还没实现。
class DemoEntry {
  const DemoEntry({
    required this.id,
    required this.title,
    required this.summary,
    required this.concepts,
    this.pageBuilder,
  });

  final String id;
  final String title;
  final String summary;

  /// 本课涉及的 Riverpod API，直接展示在首页卡片上，方便复习。
  final List<String> concepts;

  final WidgetBuilder? pageBuilder;
}

/// 全部课程目录（顺序即建议学习顺序）。
const List<DemoEntry> demos = [
  DemoEntry(
    id: 's1',
    title: 'S1 · 计数器',
    summary: '最基础的 Notifier：读写状态、局部重建、select 精确订阅',
    concepts: ['@riverpod class', 'ref.watch / read', 'select'],
  ),
  DemoEntry(
    id: 's2',
    title: 'S2 · 待办清单',
    summary: '不可变状态、派生 provider、ref.listen 处理副作用',
    concepts: ['Notifier<T>', '派生 Provider', 'ref.listen'],
  ),
  DemoEntry(
    id: 's3',
    title: 'S3 · 异步三态',
    summary: 'AsyncNotifier 与 AsyncValue 的 loading / error / data',
    concepts: ['AsyncNotifier', 'AsyncValue', 'ref.invalidate'],
  ),
  DemoEntry(
    id: 's4',
    title: 'S4 · 搜索与生命周期',
    summary: 'family 参数化、autoDispose、防抖搜索与 keepAlive',
    concepts: ['family', 'autoDispose', 'ref.onDispose'],
  ),
  DemoEntry(
    id: 's5',
    title: 'S5 · 依赖注入与测试',
    summary: '仓库抽象 + overrides 注入 Fake + ProviderContainer 单测',
    concepts: ['Provider 抽象', 'overrides', 'ProviderContainer'],
  ),
];
