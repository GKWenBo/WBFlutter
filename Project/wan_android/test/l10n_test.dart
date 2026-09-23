// 测国际化：直接 load 出某语言的 AppLocalizations 实例，验证翻译 + ICU 复数/占位符。
// 用 delegate.load(Locale) 拿实例，不用 pump 整个 App，测起来干净直接。

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wan_android/l10n/app_localizations.dart';

void main() {
  test('支持 en 和 zh 两种语言', () {
    final codes = AppLocalizations.supportedLocales
        .map((l) => l.languageCode)
        .toList();
    expect(codes, containsAll(['en', 'zh']));
  });

  test('中文：Tab 标签 + 占位符文案正确', () async {
    final zh = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(zh.navHome, '首页');
    expect(zh.navCart, '购物车');
    // 占位符：把变量拼进翻译（≈ String(format:)）。
    expect(zh.currentEnv('dev'), '当前环境：dev');
  });

  test('英文：同样的 key 取到英文', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(en.navHome, 'Home');
    expect(en.navCart, 'Cart');
  });

  test('ICU 复数：0/1/多 自动选不同措辞（中文）', () async {
    final zh = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(zh.cartItemCount(0), '购物车是空的');
    expect(zh.cartItemCount(3), contains('3'));
    expect(zh.cartItemCount(3), contains('件商品'));
  });

  test('ICU 复数：英文 =1 用单数 item、其它用复数 items', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(en.cartItemCount(0), 'Cart is empty');
    expect(en.cartItemCount(1), contains('item in cart'));
    expect(en.cartItemCount(5), contains('items in cart'));
  });
}
