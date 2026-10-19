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

  @override
  String get retry => '重试';

  @override
  String get reload => '重新加载';

  @override
  String get errorNetworkTimeout => '网络超时，请稍后重试';

  @override
  String get errorNoConnection => '无法连接服务器，请检查网络';

  @override
  String errorServer(String code) {
    return '服务器开小差了（$code）';
  }

  @override
  String get errorParse => '数据解析失败';

  @override
  String get errorInvalidCredentials => '用户名或密码错误';

  @override
  String get errorUnknown => '出了点问题，请稍后重试';

  @override
  String actionFailed(String reason) {
    return '操作失败：$reason';
  }

  @override
  String priceValue(double amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.simpleCurrency(locale: localeName, name: 'USD');
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString';
  }

  @override
  String totalAmount(double amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.simpleCurrency(locale: localeName, name: 'USD');
    final String amountString = amountNumberFormat.format(amount);

    return '合计：$amountString';
  }

  @override
  String unitPriceTimesQuantity(double price, int quantity) {
    final intl.NumberFormat priceNumberFormat =
        intl.NumberFormat.simpleCurrency(locale: localeName, name: 'USD');
    final String priceString = priceNumberFormat.format(price);

    return '$priceString × $quantity';
  }

  @override
  String get searchHint => '搜索商品';

  @override
  String get recommendedForYou => '为你推荐';

  @override
  String get seeAll => '查看全部';

  @override
  String get loadMoreFailed => '加载更多失败，点击重试';

  @override
  String get offlineBanner => '网络不可用，正在展示上次的商品数据';

  @override
  String get categoryPhones => '手机';

  @override
  String get categoryLaptops => '电脑';

  @override
  String get categoryWatches => '手表';

  @override
  String get categoryFashion => '穿搭';

  @override
  String get categoryAccessories => '配件';

  @override
  String get categoryBeauty => '美妆';

  @override
  String get productsEmpty => '没有找到商品';

  @override
  String get productDetailTitle => '商品详情';

  @override
  String discountBadge(double percent) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.percentPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '$percentString';
  }

  @override
  String ratingValue(double rating) {
    final intl.NumberFormat ratingNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String ratingString = ratingNumberFormat.format(rating);

    return '$ratingString';
  }

  @override
  String stockCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '库存 $countString';
  }

  @override
  String get productDescription => '商品介绍';

  @override
  String get favoriteAdd => '收藏';

  @override
  String get favoriteRemove => '取消收藏';

  @override
  String get addToCart => '加入购物车';

  @override
  String addedToCart(String title) {
    return '已加入购物车：$title';
  }

  @override
  String get searchPrompt => '输入关键词搜索商品';

  @override
  String searchNoResults(String query) {
    return '没有找到与“$query”相关的商品';
  }

  @override
  String get cartTitle => '购物车';

  @override
  String get cartClear => '清空购物车';

  @override
  String get cartEmpty => '购物车是空的，快去逛逛吧';

  @override
  String get cartCheckout => '去结算';

  @override
  String get categoriesTitle => '分类';

  @override
  String get favoritesTitle => '我的收藏';

  @override
  String get favoritesEmpty => '还没有收藏的商品，去详情页点 ♥ 收藏吧';

  @override
  String favoritesLoadFailed(String reason) {
    return '收藏读取失败：$reason';
  }

  @override
  String get ordersTitle => '我的订单';

  @override
  String get ordersEmpty => '还没有订单，去下一单试试吧';

  @override
  String ordersLoadFailed(String reason) {
    return '订单读取失败：$reason';
  }

  @override
  String get orderPendingCartSync => '订单已创建，购物车尚未同步';

  @override
  String get orderPendingAddressSave => '订单已创建，默认地址尚未保存';

  @override
  String orderNumber(String id) {
    return '单号 $id';
  }

  @override
  String orderItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '共 $count 件',
    );
    return '$_temp0';
  }

  @override
  String orderSummary(DateTime time, String items, double amount) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.yMd(
      localeName,
    ).add_Hm();
    final String timeString = timeDateFormat.format(time);

    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.simpleCurrency(locale: localeName, name: 'USD');
    final String amountString = amountNumberFormat.format(amount);

    return '$timeString · $items · $amountString';
  }

  @override
  String get orderStatusSubmitted => '已提交';

  @override
  String get orderStatusPaid => '已支付';

  @override
  String get orderStatusShipped => '已发货';

  @override
  String get checkoutTitle => '确认订单';

  @override
  String get checkoutEmpty => '购物车是空的，没什么可结算的';

  @override
  String get shippingInfo => '收货信息';

  @override
  String get recipientLabel => '收货人';

  @override
  String get recipientRequired => '请填写收货人';

  @override
  String get phoneLabel => '手机号';

  @override
  String get phoneRequired => '请填写手机号';

  @override
  String get phoneInvalid => '手机号应为 11 位数字';

  @override
  String get addressLabel => '详细地址';

  @override
  String get addressRequired => '请填写详细地址';

  @override
  String get orderItems => '商品清单';

  @override
  String get submitOrder => '提交订单';

  @override
  String get checkoutNothingToRetry => '没有待恢复的订单';

  @override
  String get retryCheckout => '重试完成结算';

  @override
  String get orderCreatedCartSyncFailed => '订单已创建，购物车同步失败，请点击重试完成结算';

  @override
  String get orderPlacedAddressNotSaved => '下单成功，默认地址尚未保存，可在订单页重试';

  @override
  String get orderPlaced => '下单成功！';

  @override
  String orderFailed(String reason) {
    return '下单失败：$reason';
  }

  @override
  String get profileTitle => '我的';

  @override
  String get logout => '退出登录';

  @override
  String profileLoadFailed(String reason) {
    return '加载用户信息失败：$reason';
  }

  @override
  String get notLoggedIn => '未登录';

  @override
  String get language => '语言';

  @override
  String get languageFollowSystem => '跟随系统';

  @override
  String get languagePickerTitle => '选择语言';

  @override
  String get loginTitle => '登录';

  @override
  String loginTestAccount(String username, String password) {
    return '测试账号：$username / $password';
  }

  @override
  String get usernameLabel => '用户名';

  @override
  String get usernameRequired => '请输入用户名';

  @override
  String get passwordLabel => '密码';

  @override
  String get passwordRequired => '请输入密码';

  @override
  String get loginSubmit => '登录';

  @override
  String loginFailed(String reason) {
    return '登录失败：$reason';
  }
}
