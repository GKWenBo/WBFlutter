import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// JSON 读写的公共基础设施，≈ UserDefaults 编解码适配器。
/// 业务模块保留键名和模型规则；false 与异常都算保存失败。
class JsonPreferencesStore {
  JsonPreferencesStore({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;
  final Future<SharedPreferences> Function() _preferences;

  Future<Object?> read(String key) async {
    final raw = (await _preferences()).getString(key);
    return raw == null ? null : jsonDecode(raw);
  }

  Future<void> write(String key, Object value) async {
    final saved = await (await _preferences()).setString(
      key,
      jsonEncode(value),
    );
    if (!saved) throw StateError('本地数据保存失败');
  }
}
