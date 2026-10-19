import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wan_android/l10n/app_localizations.dart';

// 测国际化：直接 load 出某语言的 AppLocalizations 实例，验证翻译 + ICU 复数/占位符。
// 用 delegate.load(Locale) 拿实例，不用 pump 整个 App，测起来干净直接。

Future<AppLocalizations> load(String code) =>
    AppLocalizations.delegate.load(Locale(code));

/// 不换行空格 U+00A0。intl/CLDR 在 "1.234,50 $"、"9 %" 里用的是它而不是普通空格——
/// 目的是保证金额和货币符号永远不会被折到两行。肉眼完全看不出区别，
/// 测试里写普通空格会报 "Expected: 1.234,50 $ / Actual: 1.234,50 $ / Which: is different"。
const nbsp = '\u00A0';

/// 读一个 ARB 文件，只保留"消息"键（去掉 @@locale 和 @xxx 元数据）。
Map<String, String> messages(String code) {
  final json =
      jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final e in json.entries)
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };
}

void main() {
  // M12 进阶的坑：单独 load AppLocalizations 做单测时，DateTime 占位符内部调 DateFormat，
  // 会抛 LocaleDataException（日期符号表没初始化）。App 里不会遇到——
  // GlobalMaterialLocalizations.delegate 加载时顺手初始化了；单测只 load 我们自己的 delegate 就得手动来。
  setUpAll(initializeDateFormatting);

  group('语言清单', () {
    test('支持 en / zh / de / ar 四种语言', () {
      final codes = AppLocalizations.supportedLocales
          .map((l) => l.languageCode)
          .toList();
      expect(codes, containsAll(['en', 'zh', 'de', 'ar']));
    });

    test('兜底语言是 en（排第一），不是字母序排第一的 ar', () {
      // 系统语言都不支持时 MaterialApp 用 supportedLocales.first。
      // 删掉 l10n.yaml 的 preferred-supported-locales，这条就会挂——日语用户会看到阿语 + RTL。
      expect(AppLocalizations.supportedLocales.first, const Locale('en'));
    });
  });

  group('ARB 一致性（≈ 给翻译文件做 lint，CI 里防漏翻）', () {
    final template = messages('en');
    final templateMeta =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;

    for (final code in ['zh', 'de', 'ar']) {
      test('$code 的 key 集合与模板 en 完全一致', () {
        final keys = messages(code).keys.toSet();
        // 缺 key 时 gen-l10n 不报错，只会运行时悄悄回退成英文——所以要靠测试拦。
        expect(
          template.keys.toSet().difference(keys),
          isEmpty,
          reason: '$code 缺翻译',
        );
        // 多出来的 key 通常是模板里删了/改名了，译文成了死代码。
        expect(
          keys.difference(template.keys.toSet()),
          isEmpty,
          reason: '$code 有多余 key',
        );
      });

      test('$code 的译文保留了模板声明的每个占位符', () {
        final translated = messages(code);
        for (final key in template.keys) {
          final meta = templateMeta['@$key'] as Map<String, dynamic>?;
          final placeholders =
              (meta?['placeholders'] as Map<String, dynamic>?)?.keys ??
              const <String>[];
          for (final name in placeholders) {
            // 漏了 {amount} 的译文能编译通过，但用户永远看不到价格。
            expect(
              translated[key],
              contains('{$name'),
              reason: '$code.$key 丢了 {$name}',
            );
          }
        }
      });
    }
  });

  group('翻译与占位符', () {
    test('中文：Tab 标签 + 占位符文案正确', () async {
      final zh = await load('zh');
      expect(zh.navHome, '首页');
      expect(zh.navCart, '购物车');
      // 占位符：把变量拼进翻译（≈ String(format:)）。
      expect(zh.currentEnv('dev'), '当前环境：dev');
    });

    test('英文：同样的 key 取到英文', () async {
      final en = await load('en');
      expect(en.navHome, 'Home');
      expect(en.navCart, 'Cart');
    });

    test('德语 / 阿语：同一个 key 取到各自的语言', () async {
      expect((await load('de')).navCart, 'Warenkorb');
      expect((await load('ar')).navCart, 'السلة');
    });

    test('引号属于语言：zh “…”、de „…“、ar «…»', () async {
      expect((await load('zh')).searchNoResults('手机'), contains('“手机”'));
      expect((await load('de')).searchNoResults('Handy'), contains('„Handy“'));
      expect((await load('ar')).searchNoResults('x'), contains('«x»'));
    });
  });

  group('ICU 复数', () {
    test('中文：0 / 多 两种措辞', () async {
      final zh = await load('zh');
      expect(zh.cartItemCount(0), '购物车是空的');
      expect(zh.cartItemCount(3), '购物车有 3 件商品');
    });

    test('英文：=1 用单数 item、其它用复数 items', () async {
      final en = await load('en');
      expect(en.cartItemCount(0), 'Cart is empty');
      expect(en.cartItemCount(1), '1 item in cart');
      expect(en.cartItemCount(5), '5 items in cart');
    });

    test('阿拉伯语：六种复数形式 zero/one/two/few/many/other', () async {
      final ar = await load('ar');
      // CLDR 阿语规则：0→zero，1→one，2→two（双数，专门的词形），
      // 3–10→few（复数），11–99→many（数词后跟单数宾格），100+→other。
      expect(ar.orderItemCount(0), 'لا منتجات');
      expect(ar.orderItemCount(1), 'منتج واحد');
      expect(ar.orderItemCount(2), 'منتجان');
      expect(ar.orderItemCount(3), '3 منتجات');
      expect(ar.orderItemCount(10), '10 منتجات');
      expect(ar.orderItemCount(11), '11 منتجًا');
      expect(ar.orderItemCount(99), '99 منتجًا');
      expect(ar.orderItemCount(100), '100 منتج');
      // 103 % 100 = 3 → 又回到 few：规则看的是"除以 100 的余数"，不是数值大小。
      expect(ar.orderItemCount(103), '103 منتجات');
    });
  });

  group('数字 / 货币 / 百分比 / 日期跟着语言走', () {
    test('金额：同样是美元，en/zh 是 \$1,234.50，de 是 1.234,50 \$', () async {
      expect((await load('en')).priceValue(1234.5), r'$1,234.50');
      expect((await load('zh')).priceValue(1234.5), r'$1,234.50');
      expect((await load('de')).priceValue(1234.5), '1.234,50$nbsp\$');
      // 阿语：数字保持西式（intl 0.20 的 ar 默认 latn 数字），
      // 但会插入不可见的 RLM(U+200F) 方向标记，所以别用 == 断言整串。
      final ar = (await load('ar')).priceValue(1234.5);
      expect(ar, contains('1,234.50'));
      expect(ar, contains('‏'));
    });

    test('百分比：de 在 % 前加空格', () async {
      expect((await load('en')).discountBadge(0.085), '-9%');
      expect((await load('de')).discountBadge(0.085), '-9$nbsp%');
    });

    test('一位小数评分：de 用逗号', () async {
      expect((await load('en')).ratingValue(4.5), '4.5');
      expect((await load('de')).ratingValue(4.5), '4,5');
    });

    test('日期：zh 年/月/日，de 日.月.年', () async {
      final time = DateTime(2026, 3, 7, 9, 5);
      final zh = await load('zh');
      final de = await load('de');
      expect(
        zh.orderSummary(time, zh.orderItemCount(3), 10),
        r'2026/3/7 09:05 · 共 3 件 · $10.00',
      );
      expect(
        de.orderSummary(time, de.orderItemCount(3), 10),
        '7.3.2026 09:05 · 3 Artikel · 10,00$nbsp\$',
      );
    });
  });
}
