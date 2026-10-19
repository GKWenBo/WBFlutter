import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wan_android/core/error/error_messages.dart';
import 'package:wan_android/core/error/failure.dart';
import 'package:wan_android/core/storage/json_preferences_store.dart';
import 'package:wan_android/core/text/normalize_digits.dart';
import 'package:wan_android/features/settings/api.dart';
import 'package:wan_android/features/settings/data/locale_storage.dart';
import 'package:wan_android/features/settings/data/settings_dependencies.dart';
import 'package:wan_android/l10n/app_localizations.dart';

// M12 国际化进阶的"非文案"部分：错误翻译、数字归一化、语言偏好持久化。

/// 内存版语言存储：可控制保存失败 / 保存阻塞。
class MemoryLocaleStorage extends LocaleStorage {
  MemoryLocaleStorage([this.persisted]);
  Locale? persisted;
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<Locale?> load() async => persisted;

  @override
  Future<void> save(Locale? locale) async {
    await gate?.future;
    if (fail) throw StateError('写入失败');
    persisted = locale;
  }
}

class BrokenStore extends JsonPreferencesStore {
  @override
  Future<Object?> read(String key) async => throw StateError('读取失败');
}

void main() {
  group('describeError：数据层只给类型，UI 层翻译成当前语言', () {
    test('同一个异常，按用户语言给出不同文案', () async {
      final zh = await AppLocalizations.delegate.load(const Locale('zh'));
      final de = await AppLocalizations.delegate.load(const Locale('de'));
      const timeout = NetworkException('网络超时', issue: NetworkIssue.timeout);
      expect(zh.describeError(timeout), '网络超时，请稍后重试');
      expect(de.describeError(timeout), contains('Zeitüberschreitung'));
    });

    test('NetworkIssue 区分"超时"与"连不上"', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        en.describeError(const NetworkException('x')),
        en.errorNoConnection,
      );
      expect(
        en.describeError(
          const NetworkException('x', issue: NetworkIssue.timeout),
        ),
        en.errorNetworkTimeout,
      );
    });

    test('ServerException 把状态码填进占位符', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        en.describeError(const ServerException('x', code: 503)),
        contains('503'),
      );
    });

    test('非 AppException（内部错误）不泄露开发者的中文诊断信息', () async {
      final de = await AppLocalizations.delegate.load(const Locale('de'));
      final text = de.describeError(StateError('本地数据保存失败'));
      expect(text, de.errorUnknown);
      expect(text, isNot(contains('本地')));
    });
  });

  group('normalizeDigits：阿语键盘输入的数字', () {
    test('阿拉伯-印度数字 ٠–٩ → 0–9', () {
      expect(normalizeDigits('١٣٨٠٠١٣٨٠٠٠'), '13800138000');
      // 原始字符串 int.tryParse 不认，这正是要归一化的原因。
      expect(int.tryParse('١٣٨'), isNull);
    });

    test('东阿拉伯-印度数字 ۰–۹（波斯语/乌尔都语键盘）→ 0–9', () {
      expect(normalizeDigits('۱۳۸'), '138');
    });

    test('其他字符原样保留', () {
      expect(normalizeDigits('+86 138-٠٠'), '+86 138-00');
    });
  });

  group('LocaleStorage：语言偏好读写', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('从没选过 → null（跟随系统）', () async {
      expect(await LocaleStorage().load(), isNull);
    });

    test('存 de 再读回来', () async {
      final storage = LocaleStorage();
      await storage.save(const Locale('de'));
      expect(await storage.load(), const Locale('de'));
    });

    test('存"跟随系统"再读回来仍是 null', () async {
      final storage = LocaleStorage();
      await storage.save(const Locale('ar'));
      await storage.save(null);
      expect(await storage.load(), isNull);
    });

    test('存过的语言在新版本里被移除了 → 降级为跟随系统', () async {
      SharedPreferences.setMockInitialValues({'app_locale': '"ja"'});
      expect(await LocaleStorage().load(), isNull);
    });

    test('存储读取失败也降级为跟随系统，不拦住 App 启动', () async {
      expect(await LocaleStorage(store: BrokenStore()).load(), isNull);
    });
  });

  group('appLocaleProvider：切换语言', () {
    ProviderContainer containerWith(MemoryLocaleStorage storage) {
      final container = ProviderContainer(
        overrides: [localeStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('启动时恢复上次选择的语言', () async {
      final container = containerWith(MemoryLocaleStorage(const Locale('ar')));
      expect(
        await container.read(appLocaleProvider.future),
        const Locale('ar'),
      );
    });

    test('保存成功才发布新语言', () async {
      final storage = MemoryLocaleStorage()..gate = Completer<void>();
      final container = containerWith(storage);
      await container.read(appLocaleProvider.future);

      final pending = container
          .read(appLocaleProvider.notifier)
          .select(const Locale('de'));
      await Future<void>.delayed(Duration.zero);
      // 还没写完盘：界面不能先切成德语（写失败的话下次启动又变回去，用户会以为 App 抽风）。
      expect(container.read(appLocaleProvider).value, isNull);

      storage.gate!.complete();
      await pending;
      expect(container.read(appLocaleProvider).value, const Locale('de'));
      expect(storage.persisted, const Locale('de'));
    });

    test('保存失败保留原语言并把错误抛给调用方（UI 据此提示）', () async {
      final storage = MemoryLocaleStorage(const Locale('zh'))..fail = true;
      final container = containerWith(storage);
      await container.read(appLocaleProvider.future);

      await expectLater(
        container.read(appLocaleProvider.notifier).select(const Locale('ar')),
        throwsStateError,
      );
      expect(container.read(appLocaleProvider).value, const Locale('zh'));
    });
  });
}
