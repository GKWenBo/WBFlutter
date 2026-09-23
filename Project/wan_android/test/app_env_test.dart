// 测多环境配置：解析函数的容错 + 每套 Flavor 的关键开关。
// 注意 AppEnv.current 依赖编译期常量 --dart-define，测试里改不了；
// 所以我们把逻辑抽成了纯函数 parseFlavor / flavorConfigFor，直接测它们（这也是当初抽纯函数的原因）。

import 'package:flutter_test/flutter_test.dart';
import 'package:wan_android/core/config/app_env.dart';

void main() {
  group('parseFlavor 容错', () {
    test('识别 prod 及其别名（大小写、空格无关）', () {
      expect(parseFlavor('prod'), Flavor.prod);
      expect(parseFlavor('PROD'), Flavor.prod);
      expect(parseFlavor(' production '), Flavor.prod);
      expect(parseFlavor('release'), Flavor.prod);
    });

    test('识别 staging 及其别名', () {
      expect(parseFlavor('staging'), Flavor.staging);
      expect(parseFlavor('STG'), Flavor.staging);
      expect(parseFlavor('stage'), Flavor.staging);
    });

    test('无法识别 / 空串 一律兜底 dev（绝不会误当成 prod）', () {
      expect(parseFlavor(''), Flavor.dev);
      expect(parseFlavor('dev'), Flavor.dev);
      expect(parseFlavor('随便什么'), Flavor.dev);
      expect(parseFlavor('preprod'), Flavor.dev); // 不匹配 prod 的严格别名
    });
  });

  group('flavorConfigFor 关键开关', () {
    test('prod：关日志、不显示环境角标、标题干净', () {
      final cfg = flavorConfigFor(Flavor.prod);
      expect(cfg.enableLogging, isFalse);
      expect(cfg.showEnvBanner, isFalse);
      expect(cfg.appTitle, 'WanShop');
    });

    test('dev：开日志 + 显示环境角标', () {
      final cfg = flavorConfigFor(Flavor.dev);
      expect(cfg.enableLogging, isTrue);
      expect(cfg.showEnvBanner, isTrue);
      expect(cfg.appTitle, contains('Dev'));
    });

    test('三套环境都返回自洽的 flavor 字段', () {
      for (final f in Flavor.values) {
        expect(flavorConfigFor(f).flavor, f);
      }
    });
  });
}
