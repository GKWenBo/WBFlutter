import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
    Locale('de'),
    Locale('zh'),
  ];

  /// Bottom tab label: products home
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom tab label: categories
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get navCategory;

  /// Bottom tab label: shopping cart
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get navCart;

  /// Bottom tab label: user profile
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Cart summary on the profile page, ICU plural
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Cart is empty} =1{{count} item in cart} other{{count} items in cart}}'**
  String cartItemCount(int count);

  /// Shows the current build flavor on the profile page
  ///
  /// In en, this message translates to:
  /// **'Environment: {name}'**
  String currentEnv(String name);

  /// Generic button: try the failed operation again
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Button on the offline banner: reload data from the network
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// Error shown when a request times out
  ///
  /// In en, this message translates to:
  /// **'The network timed out. Please try again later.'**
  String get errorNetworkTimeout;

  /// Error shown when the device can't connect to the server
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Please check your connection.'**
  String get errorNoConnection;

  /// Error shown when the server returns a non-2xx status code
  ///
  /// In en, this message translates to:
  /// **'The server ran into a problem ({code}).'**
  String errorServer(String code);

  /// Error shown when the response can't be decoded
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read the data we received.'**
  String get errorParse;

  /// Fallback error for anything we can't classify
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorUnknown;

  /// Snackbar after a user action (add to cart, clear cart, sign out…) fails
  ///
  /// In en, this message translates to:
  /// **'Action failed: {reason}'**
  String actionFailed(String reason);

  /// A single price. Prices are always in US dollars; only the formatting follows the locale
  ///
  /// In en, this message translates to:
  /// **'{amount}'**
  String priceValue(double amount);

  /// Order total in the cart / checkout bottom bar
  ///
  /// In en, this message translates to:
  /// **'Total: {amount}'**
  String totalAmount(double amount);

  /// Line item on checkout / order detail: unit price times quantity
  ///
  /// In en, this message translates to:
  /// **'{price} × {quantity}'**
  String unitPriceTimesQuantity(double price, int quantity);

  /// Placeholder of the search box (home page and search page)
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get searchHint;

  /// Section title above the product grid on the home page
  ///
  /// In en, this message translates to:
  /// **'Recommended for you'**
  String get recommendedForYou;

  /// Small text button on the right of a section title
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// Shown at the bottom of the product list when loading the next page fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more. Tap to retry.'**
  String get loadMoreFailed;

  /// Banner above the home product grid when data comes from the offline cache
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Showing the products from last time.'**
  String get offlineBanner;

  /// Home page shortcut: smartphones category
  ///
  /// In en, this message translates to:
  /// **'Phones'**
  String get categoryPhones;

  /// Home page shortcut: laptops category
  ///
  /// In en, this message translates to:
  /// **'Laptops'**
  String get categoryLaptops;

  /// Home page shortcut: watches category
  ///
  /// In en, this message translates to:
  /// **'Watches'**
  String get categoryWatches;

  /// Home page shortcut: clothing category
  ///
  /// In en, this message translates to:
  /// **'Fashion'**
  String get categoryFashion;

  /// Home page shortcut: mobile accessories category
  ///
  /// In en, this message translates to:
  /// **'Accessories'**
  String get categoryAccessories;

  /// Home page shortcut: beauty / cosmetics category
  ///
  /// In en, this message translates to:
  /// **'Beauty'**
  String get categoryBeauty;

  /// Empty state of a product grid
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get productsEmpty;

  /// App bar title on the product detail page while loading / on error
  ///
  /// In en, this message translates to:
  /// **'Product details'**
  String get productDetailTitle;

  /// Discount badge next to the price. percent is a fraction (0.085 = 8.5%); the percent sign position follows the locale
  ///
  /// In en, this message translates to:
  /// **'-{percent}'**
  String discountBadge(double percent);

  /// Star rating with one decimal digit (4.5 / 4,5)
  ///
  /// In en, this message translates to:
  /// **'{rating}'**
  String ratingValue(double rating);

  /// Remaining stock on the product detail page
  ///
  /// In en, this message translates to:
  /// **'In stock: {count}'**
  String stockCount(int count);

  /// Section title above the product description
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get productDescription;

  /// Tooltip of the heart button when the product is not a favorite yet
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get favoriteAdd;

  /// Tooltip of the heart button when the product is already a favorite
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get favoriteRemove;

  /// Main button on the product detail page
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get addToCart;

  /// Snackbar after adding a product to the cart
  ///
  /// In en, this message translates to:
  /// **'Added to cart: {title}'**
  String addedToCart(String title);

  /// Search page body before the user typed anything
  ///
  /// In en, this message translates to:
  /// **'Type a keyword to search'**
  String get searchPrompt;

  /// Empty state of the search results. Use the quotation marks of your language
  ///
  /// In en, this message translates to:
  /// **'No products match “{query}”'**
  String searchNoResults(String query);

  /// App bar title of the cart page
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cartTitle;

  /// Tooltip of the trash button on the cart page
  ///
  /// In en, this message translates to:
  /// **'Clear cart'**
  String get cartClear;

  /// Empty state of the cart page
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty. Go find something you like!'**
  String get cartEmpty;

  /// Button in the cart bottom bar that opens the checkout page
  ///
  /// In en, this message translates to:
  /// **'Check out'**
  String get cartCheckout;

  /// App bar title of the categories page
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// Favorites page title and the profile menu row that opens it
  ///
  /// In en, this message translates to:
  /// **'My favorites'**
  String get favoritesTitle;

  /// Empty state of the favorites page
  ///
  /// In en, this message translates to:
  /// **'No favorites yet. Tap ♥ on a product to save it.'**
  String get favoritesEmpty;

  /// Error state of the favorites page
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load favorites: {reason}'**
  String favoritesLoadFailed(String reason);

  /// Orders page title and the profile menu row that opens it
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get ordersTitle;

  /// Empty state of the orders page
  ///
  /// In en, this message translates to:
  /// **'No orders yet. Why not place your first one?'**
  String get ordersEmpty;

  /// Error state of the orders page
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load orders: {reason}'**
  String ordersLoadFailed(String reason);

  /// Warning row on the orders page; next to a Retry button
  ///
  /// In en, this message translates to:
  /// **'Order created, but the cart hasn\'t synced yet'**
  String get orderPendingCartSync;

  /// Warning row on the orders page; next to a Retry button
  ///
  /// In en, this message translates to:
  /// **'Order created, but the default address hasn\'t been saved'**
  String get orderPendingAddressSave;

  /// Order card title
  ///
  /// In en, this message translates to:
  /// **'Order #{id}'**
  String orderNumber(String id);

  /// Total number of items in one order, used inside orderSummary
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} item} other{{count} items}}'**
  String orderItemCount(int count);

  /// Order card subtitle: creation time, item count (orderItemCount) and total price
  ///
  /// In en, this message translates to:
  /// **'{time} · {items} · {amount}'**
  String orderSummary(DateTime time, String items, double amount);

  /// Order status badge
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get orderStatusSubmitted;

  /// Order status badge
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get orderStatusPaid;

  /// Order status badge
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get orderStatusShipped;

  /// App bar title of the checkout page
  ///
  /// In en, this message translates to:
  /// **'Confirm order'**
  String get checkoutTitle;

  /// Checkout page body when the cart is empty
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty — nothing to check out.'**
  String get checkoutEmpty;

  /// Section title above the address form
  ///
  /// In en, this message translates to:
  /// **'Shipping details'**
  String get shippingInfo;

  /// Address form field: name of the person receiving the parcel
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get recipientLabel;

  /// Validation error of the recipient field
  ///
  /// In en, this message translates to:
  /// **'Please enter the recipient\'s name'**
  String get recipientRequired;

  /// Address form field
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneLabel;

  /// Validation error of the phone field
  ///
  /// In en, this message translates to:
  /// **'Please enter a phone number'**
  String get phoneRequired;

  /// Validation error of the phone field (the shop only ships to mainland China numbers)
  ///
  /// In en, this message translates to:
  /// **'The phone number must have 11 digits'**
  String get phoneInvalid;

  /// Address form field: full street address
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressLabel;

  /// Validation error of the address field
  ///
  /// In en, this message translates to:
  /// **'Please enter the address'**
  String get addressRequired;

  /// Section title above the read-only item list on checkout
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get orderItems;

  /// Final button that places the order. Some markets have legal wording requirements (e.g. Germany)
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get submitOrder;

  /// Checkout button label when the order exists but syncing the cart failed
  ///
  /// In en, this message translates to:
  /// **'Retry checkout'**
  String get retryCheckout;

  /// Snackbar on checkout
  ///
  /// In en, this message translates to:
  /// **'Order created, but syncing the cart failed. Tap retry to finish checking out.'**
  String get orderCreatedCartSyncFailed;

  /// Snackbar after a successful order whose address couldn't be saved
  ///
  /// In en, this message translates to:
  /// **'Order placed. The default address wasn\'t saved — you can retry from the orders page.'**
  String get orderPlacedAddressNotSaved;

  /// Snackbar after a successful order
  ///
  /// In en, this message translates to:
  /// **'Order placed!'**
  String get orderPlaced;

  /// Snackbar when placing the order fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t place the order: {reason}'**
  String orderFailed(String reason);

  /// App bar title of the profile page
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Tooltip of the sign-out button on the profile page
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logout;

  /// Error state of the profile page
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your profile: {reason}'**
  String profileLoadFailed(String reason);

  /// Profile page fallback when there is no user
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notLoggedIn;

  /// Tooltip of the language button and title of the language menu row
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Language option: use the phone's language
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageFollowSystem;

  /// Title of the language picker bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get languagePickerTitle;

  /// App bar title of the sign-in page
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// Hint under the logo showing the demo credentials
  ///
  /// In en, this message translates to:
  /// **'Test account: {username} / {password}'**
  String loginTestAccount(String username, String password);

  /// Sign-in form field
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// Validation error of the username field
  ///
  /// In en, this message translates to:
  /// **'Please enter your username'**
  String get usernameRequired;

  /// Sign-in form field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Validation error of the password field
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get passwordRequired;

  /// Submit button of the sign-in form (separate key from the page title on purpose)
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSubmit;

  /// Snackbar when sign-in fails
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: {reason}'**
  String loginFailed(String reason);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'de', 'en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
