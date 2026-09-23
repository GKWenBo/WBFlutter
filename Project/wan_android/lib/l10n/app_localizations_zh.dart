// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get navHome => '首页';

  @override
  String get navCategory => '分类';

  @override
  String get navCart => '购物车';

  @override
  String get navProfile => '我的';

  @override
  String cartItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '购物车有 $count 件商品',
      zero: '购物车是空的',
    );
    return '$_temp0';
  }

  @override
  String currentEnv(String name) {
    return '当前环境：$name';
  }
}
