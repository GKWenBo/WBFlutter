// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navCategory => 'Category';

  @override
  String get navCart => 'Cart';

  @override
  String get navProfile => 'Profile';

  @override
  String cartItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items in cart',
      one: '$count item in cart',
      zero: 'Cart is empty',
    );
    return '$_temp0';
  }

  @override
  String currentEnv(String name) {
    return 'Environment: $name';
  }

  @override
  String get retry => 'Retry';

  @override
  String get reload => 'Reload';

  @override
  String get errorNetworkTimeout =>
      'The network timed out. Please try again later.';

  @override
  String get errorNoConnection =>
      'Can\'t reach the server. Please check your connection.';

  @override
  String errorServer(String code) {
    return 'The server ran into a problem ($code).';
  }

  @override
  String get errorParse => 'We couldn\'t read the data we received.';

  @override
  String get errorInvalidCredentials => 'Incorrect username or password.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';

  @override
  String actionFailed(String reason) {
    return 'Action failed: $reason';
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

    return 'Total: $amountString';
  }

  @override
  String unitPriceTimesQuantity(double price, int quantity) {
    final intl.NumberFormat priceNumberFormat =
        intl.NumberFormat.simpleCurrency(locale: localeName, name: 'USD');
    final String priceString = priceNumberFormat.format(price);

    return '$priceString × $quantity';
  }

  @override
  String get searchHint => 'Search products';

  @override
  String get recommendedForYou => 'Recommended for you';

  @override
  String get seeAll => 'See all';

  @override
  String get loadMoreFailed => 'Couldn\'t load more. Tap to retry.';

  @override
  String get offlineBanner =>
      'You\'re offline. Showing the products from last time.';

  @override
  String get categoryPhones => 'Phones';

  @override
  String get categoryLaptops => 'Laptops';

  @override
  String get categoryWatches => 'Watches';

  @override
  String get categoryFashion => 'Fashion';

  @override
  String get categoryAccessories => 'Accessories';

  @override
  String get categoryBeauty => 'Beauty';

  @override
  String get productsEmpty => 'No products found';

  @override
  String get productDetailTitle => 'Product details';

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

    return 'In stock: $countString';
  }

  @override
  String get productDescription => 'Description';

  @override
  String get favoriteAdd => 'Add to favorites';

  @override
  String get favoriteRemove => 'Remove from favorites';

  @override
  String get addToCart => 'Add to cart';

  @override
  String addedToCart(String title) {
    return 'Added to cart: $title';
  }

  @override
  String get searchPrompt => 'Type a keyword to search';

  @override
  String searchNoResults(String query) {
    return 'No products match “$query”';
  }

  @override
  String get cartTitle => 'Cart';

  @override
  String get cartClear => 'Clear cart';

  @override
  String get cartEmpty => 'Your cart is empty. Go find something you like!';

  @override
  String get cartCheckout => 'Check out';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get favoritesTitle => 'My favorites';

  @override
  String get favoritesEmpty =>
      'No favorites yet. Tap ♥ on a product to save it.';

  @override
  String favoritesLoadFailed(String reason) {
    return 'Couldn\'t load favorites: $reason';
  }

  @override
  String get ordersTitle => 'My orders';

  @override
  String get ordersEmpty => 'No orders yet. Why not place your first one?';

  @override
  String ordersLoadFailed(String reason) {
    return 'Couldn\'t load orders: $reason';
  }

  @override
  String get orderPendingCartSync =>
      'Order created, but the cart hasn\'t synced yet';

  @override
  String get orderPendingAddressSave =>
      'Order created, but the default address hasn\'t been saved';

  @override
  String orderNumber(String id) {
    return 'Order #$id';
  }

  @override
  String orderItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
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
  String get orderStatusSubmitted => 'Submitted';

  @override
  String get orderStatusPaid => 'Paid';

  @override
  String get orderStatusShipped => 'Shipped';

  @override
  String get checkoutTitle => 'Confirm order';

  @override
  String get checkoutEmpty => 'Your cart is empty — nothing to check out.';

  @override
  String get shippingInfo => 'Shipping details';

  @override
  String get recipientLabel => 'Recipient';

  @override
  String get recipientRequired => 'Please enter the recipient\'s name';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get phoneRequired => 'Please enter a phone number';

  @override
  String get phoneInvalid => 'The phone number must have 11 digits';

  @override
  String get addressLabel => 'Address';

  @override
  String get addressRequired => 'Please enter the address';

  @override
  String get orderItems => 'Items';

  @override
  String get submitOrder => 'Place order';

  @override
  String get checkoutNothingToRetry =>
      'There\'s no unfinished order to resume.';

  @override
  String get retryCheckout => 'Retry checkout';

  @override
  String get orderCreatedCartSyncFailed =>
      'Order created, but syncing the cart failed. Tap retry to finish checking out.';

  @override
  String get orderPlacedAddressNotSaved =>
      'Order placed. The default address wasn\'t saved — you can retry from the orders page.';

  @override
  String get orderPlaced => 'Order placed!';

  @override
  String orderFailed(String reason) {
    return 'Couldn\'t place the order: $reason';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String get logout => 'Sign out';

  @override
  String profileLoadFailed(String reason) {
    return 'Couldn\'t load your profile: $reason';
  }

  @override
  String get notLoggedIn => 'Not signed in';

  @override
  String get language => 'Language';

  @override
  String get languageFollowSystem => 'System default';

  @override
  String get languagePickerTitle => 'Choose language';

  @override
  String get loginTitle => 'Sign in';

  @override
  String loginTestAccount(String username, String password) {
    return 'Test account: $username / $password';
  }

  @override
  String get usernameLabel => 'Username';

  @override
  String get usernameRequired => 'Please enter your username';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordRequired => 'Please enter your password';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String loginFailed(String reason) {
    return 'Sign-in failed: $reason';
  }
}
