import 'package:flutter/material.dart';

import '../versions/v0_setstate/v0_shop_root.dart';
import '../versions/v1_provider/v1_shop_root.dart';
import '../versions/v2_bloc/v2_shop_root.dart';

/// 一个「同题异解」的 MiniShop 版本条目。
/// 类比 NativeLab 的 lessonRegistry：builder == null 即未解锁（门禁）。
class ShopVersion {
  const ShopVersion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.unlockLesson,
    this.builder,
  });

  final String id;
  final String title;
  final String subtitle;

  /// 哪一课解锁它（未解锁时提示用）。
  final String unlockLesson;

  /// 版本入口；null 表示还没到那一课。
  final WidgetBuilder? builder;

  bool get unlocked => builder != null;
}

/// 五版对照注册表（设计文档第 3 节）。每完成一课，把对应 builder 接上即"翻牌"。
final List<ShopVersion> versionRegistry = [
  ShopVersion(
    id: 'v0',
    title: 'v0 · setState 基线版',
    subtitle: '构造函数层层传参 + 回调上浮 + 双重 setState',
    unlockLesson: 'S0',
    builder: (_) => const V0ShopRoot(),
  ),
  ShopVersion(
    id: 'v1',
    title: 'v1 · Provider',
    subtitle: 'InheritedWidget 的工程化封装',
    unlockLesson: 'S2',
    builder: (_) => const V1ShopRoot(),
  ),
  ShopVersion(
    id: 'v2',
    title: 'v2 · Bloc',
    subtitle: '事件驱动的单向数据流',
    unlockLesson: 'S3',
    builder: (_) => const V2ShopRoot(),
  ),
  const ShopVersion(
    id: 'v3',
    title: 'v3 · GetX',
    subtitle: 'Rx 响应式 + 依赖注入',
    unlockLesson: 'S4',
  ),
  const ShopVersion(
    id: 'v4',
    title: 'v4 · Riverpod（结课作业）',
    subtitle: '编译期安全的 Provider 进化版',
    unlockLesson: 'S6',
  ),
];
