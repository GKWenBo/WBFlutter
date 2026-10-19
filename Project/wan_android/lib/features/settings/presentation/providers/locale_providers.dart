import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/async/serial_task_queue.dart';
import '../../data/settings_dependencies.dart';

part 'locale_providers.g.dart';

/// M12 国际化进阶：App 内手动选择的语言。null = 跟随系统。
///
/// 和收藏/购物车同一套模式（AsyncNotifier + keepAlive + 串行队列 + 保存成功才发布）：
/// - AsyncNotifier：初始值要异步读盘；
/// - keepAlive：MaterialApp 一直 watch 它，语言是整个 App 生命周期的全局状态；
/// - 保存成功才发布：如果磁盘写失败还把界面切成德语，下次启动又变回中文，用户会以为 App 抽风。
///
/// iOS 对照：iOS 13+ 的"每 App 语言"由系统设置页管理，App 只能读；
/// Flutter 这里是 App 自己管 —— MaterialApp.locale 一换，整棵树按新语言重建。
/// （两者并不冲突：Info.plist 声明了 CFBundleLocalizations 后，
///  用户在 iOS 设置里给 App 选的语言会作为"系统语言"传进来，被这里的 null 分支采用。）
@Riverpod(keepAlive: true)
class AppLocale extends _$AppLocale {
  final _queue = SerialTaskQueue();

  @override
  Future<Locale?> build() => ref.read(localeStorageProvider).load();

  /// 切换语言；传 null 表示恢复"跟随系统"。
  Future<void> select(Locale? locale) => _queue.run(() async {
    await future; // 等初始化读盘完成，避免被迟到的旧值覆盖（M7 教训）
    await ref.read(localeStorageProvider).save(locale);
    if (ref.mounted) state = AsyncData(locale);
  });
}
