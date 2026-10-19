// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navCategory => 'الفئات';

  @override
  String get navCart => 'السلة';

  @override
  String get navProfile => 'حسابي';

  @override
  String cartItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتج في السلة',
      many: '$count منتجًا في السلة',
      few: '$count منتجات في السلة',
      two: 'منتجان في السلة',
      one: 'منتج واحد في السلة',
      zero: 'سلة التسوق فارغة',
    );
    return '$_temp0';
  }

  @override
  String currentEnv(String name) {
    return 'البيئة الحالية: $name';
  }

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get reload => 'إعادة التحميل';

  @override
  String get errorNetworkTimeout => 'انتهت مهلة الاتصال، يرجى المحاولة لاحقًا';

  @override
  String get errorNoConnection =>
      'تعذّر الاتصال بالخادم، يرجى التحقق من الشبكة';

  @override
  String errorServer(String code) {
    return 'حدث خطأ في الخادم ($code)';
  }

  @override
  String get errorParse => 'تعذّرت قراءة البيانات المستلمة';

  @override
  String get errorUnknown => 'حدث خطأ ما، يرجى المحاولة مرة أخرى';

  @override
  String actionFailed(String reason) {
    return 'فشلت العملية: $reason';
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

    return 'الإجمالي: $amountString';
  }

  @override
  String unitPriceTimesQuantity(double price, int quantity) {
    final intl.NumberFormat priceNumberFormat =
        intl.NumberFormat.simpleCurrency(locale: localeName, name: 'USD');
    final String priceString = priceNumberFormat.format(price);

    return '$priceString × $quantity';
  }

  @override
  String get searchHint => 'ابحث عن المنتجات';

  @override
  String get recommendedForYou => 'مقترحات لك';

  @override
  String get seeAll => 'عرض الكل';

  @override
  String get loadMoreFailed => 'تعذّر تحميل المزيد، اضغط لإعادة المحاولة';

  @override
  String get offlineBanner =>
      'لا يوجد اتصال بالشبكة، يتم عرض آخر المنتجات المحفوظة';

  @override
  String get categoryPhones => 'الهواتف';

  @override
  String get categoryLaptops => 'الحواسيب';

  @override
  String get categoryWatches => 'الساعات';

  @override
  String get categoryFashion => 'الأزياء';

  @override
  String get categoryAccessories => 'الإكسسوارات';

  @override
  String get categoryBeauty => 'التجميل';

  @override
  String get productsEmpty => 'لم يتم العثور على منتجات';

  @override
  String get productDetailTitle => 'تفاصيل المنتج';

  @override
  String discountBadge(double percent) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.percentPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '-$percentString';
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

    return 'المتوفر: $countString';
  }

  @override
  String get productDescription => 'وصف المنتج';

  @override
  String get favoriteAdd => 'إضافة إلى المفضلة';

  @override
  String get favoriteRemove => 'إزالة من المفضلة';

  @override
  String get addToCart => 'أضف إلى السلة';

  @override
  String addedToCart(String title) {
    return 'تمت الإضافة إلى السلة: $title';
  }

  @override
  String get searchPrompt => 'أدخل كلمة للبحث عن المنتجات';

  @override
  String searchNoResults(String query) {
    return 'لا توجد منتجات مطابقة لـ «$query»';
  }

  @override
  String get cartTitle => 'سلة التسوق';

  @override
  String get cartClear => 'إفراغ السلة';

  @override
  String get cartEmpty => 'سلة التسوق فارغة، تصفّح المنتجات وأضف ما يعجبك';

  @override
  String get cartCheckout => 'إتمام الشراء';

  @override
  String get categoriesTitle => 'الفئات';

  @override
  String get favoritesTitle => 'المفضلة';

  @override
  String get favoritesEmpty =>
      'لا توجد منتجات مفضلة بعد، اضغط ♥ في صفحة المنتج لحفظه';

  @override
  String favoritesLoadFailed(String reason) {
    return 'تعذّر تحميل المفضلة: $reason';
  }

  @override
  String get ordersTitle => 'طلباتي';

  @override
  String get ordersEmpty => 'لا توجد طلبات بعد، جرّب إنشاء طلبك الأول';

  @override
  String ordersLoadFailed(String reason) {
    return 'تعذّر تحميل الطلبات: $reason';
  }

  @override
  String get orderPendingCartSync =>
      'تم إنشاء الطلب، لكن لم تتم مزامنة السلة بعد';

  @override
  String get orderPendingAddressSave =>
      'تم إنشاء الطلب، لكن لم يتم حفظ العنوان الافتراضي بعد';

  @override
  String orderNumber(String id) {
    return 'رقم الطلب $id';
  }

  @override
  String orderItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتج',
      many: '$count منتجًا',
      few: '$count منتجات',
      two: 'منتجان',
      one: 'منتج واحد',
      zero: 'لا منتجات',
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
  String get orderStatusSubmitted => 'تم الإرسال';

  @override
  String get orderStatusPaid => 'تم الدفع';

  @override
  String get orderStatusShipped => 'تم الشحن';

  @override
  String get checkoutTitle => 'تأكيد الطلب';

  @override
  String get checkoutEmpty => 'سلة التسوق فارغة، لا يوجد ما يمكن شراؤه';

  @override
  String get shippingInfo => 'معلومات الشحن';

  @override
  String get recipientLabel => 'اسم المستلم';

  @override
  String get recipientRequired => 'يرجى إدخال اسم المستلم';

  @override
  String get phoneLabel => 'رقم الهاتف';

  @override
  String get phoneRequired => 'يرجى إدخال رقم الهاتف';

  @override
  String get phoneInvalid => 'يجب أن يتكون رقم الهاتف من 11 رقمًا';

  @override
  String get addressLabel => 'العنوان التفصيلي';

  @override
  String get addressRequired => 'يرجى إدخال العنوان التفصيلي';

  @override
  String get orderItems => 'قائمة المنتجات';

  @override
  String get submitOrder => 'إرسال الطلب';

  @override
  String get retryCheckout => 'إعادة محاولة إتمام الشراء';

  @override
  String get orderCreatedCartSyncFailed =>
      'تم إنشاء الطلب لكن فشلت مزامنة السلة، اضغط إعادة المحاولة لإتمام الشراء';

  @override
  String get orderPlacedAddressNotSaved =>
      'تم تقديم الطلب، لكن لم يتم حفظ العنوان الافتراضي، يمكنك إعادة المحاولة من صفحة الطلبات';

  @override
  String get orderPlaced => 'تم تقديم الطلب بنجاح!';

  @override
  String orderFailed(String reason) {
    return 'تعذّر تقديم الطلب: $reason';
  }

  @override
  String get profileTitle => 'حسابي';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String profileLoadFailed(String reason) {
    return 'تعذّر تحميل معلومات المستخدم: $reason';
  }

  @override
  String get notLoggedIn => 'لم يتم تسجيل الدخول';

  @override
  String get language => 'اللغة';

  @override
  String get languageFollowSystem => 'لغة النظام';

  @override
  String get languagePickerTitle => 'اختر اللغة';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String loginTestAccount(String username, String password) {
    return 'حساب تجريبي: $username / $password';
  }

  @override
  String get usernameLabel => 'اسم المستخدم';

  @override
  String get usernameRequired => 'يرجى إدخال اسم المستخدم';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get passwordRequired => 'يرجى إدخال كلمة المرور';

  @override
  String get loginSubmit => 'تسجيل الدخول';

  @override
  String loginFailed(String reason) {
    return 'فشل تسجيل الدخول: $reason';
  }
}
