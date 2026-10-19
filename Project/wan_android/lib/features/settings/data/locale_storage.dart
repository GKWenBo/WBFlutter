import 'package:flutter/widgets.dart';

import '../../../core/storage/json_preferences_store.dart';
import '../../../l10n/app_localizations.dart';

/// "App 内语言"偏好的本地持久化 ≈ 你 iOS 里存一个 UserDefaults 的 AppleLanguages 覆盖值。
///
/// 存的是 BCP-47 语言标签字符串（'de' / 'ar' / 将来的 'zh-Hant'），
/// 而不是 supportedLocales 的下标——和 M10 枚举存字符串不存下标是同一个道理：
/// 以后往列表中间插一种语言，存下标的老数据就全部错位了。
class LocaleStorage {
  static const _key = 'app_locale';
  // 用户主动切回"跟随系统"时写入的值；读取时和"从没选过"（key 不存在）一样返回 null。
  static const _followSystem = 'system';

  final JsonPreferencesStore _store;
  LocaleStorage({JsonPreferencesStore? store})
    : _store = store ?? JsonPreferencesStore();

  /// 返回 null = 跟随系统语言。
  ///
  /// 这份数据的定位接近"偏好副本"：读不出来/读出一个已下架的语言，
  /// 都降级成"跟随系统"，绝不能让一个语言偏好拦住整个 App 启动。
  Future<Locale?> load() async {
    try {
      final raw = await _store.read(_key);
      if (raw is! String || raw == _followSystem) return null;
      for (final locale in AppLocalizations.supportedLocales) {
        if (locale.toLanguageTag() == raw) return locale;
      }
      return null; // 存过的语言在新版本里被移除了 → 跟随系统
    } catch (error) {
      debugPrint('读取语言偏好失败，改为跟随系统：$error');
      return null;
    }
  }

  /// 保存失败会抛出（由 JsonPreferencesStore 抛 StateError），调用方据此不发布新状态。
  Future<void> save(Locale? locale) =>
      _store.write(_key, locale?.toLanguageTag() ?? _followSystem);
}
