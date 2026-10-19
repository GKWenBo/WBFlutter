// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get navHome => 'Start';

  @override
  String get navCategory => 'Kategorien';

  @override
  String get navCart => 'Warenkorb';

  @override
  String get navProfile => 'Profil';

  @override
  String cartItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Artikel im Warenkorb',
      zero: 'Der Warenkorb ist leer',
    );
    return '$_temp0';
  }

  @override
  String currentEnv(String name) {
    return 'Umgebung: $name';
  }

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get reload => 'Neu laden';

  @override
  String get errorNetworkTimeout =>
      'Zeitüberschreitung im Netzwerk. Bitte versuche es später erneut.';

  @override
  String get errorNoConnection =>
      'Der Server ist nicht erreichbar. Bitte überprüfe deine Verbindung.';

  @override
  String errorServer(String code) {
    return 'Beim Server ist ein Fehler aufgetreten ($code).';
  }

  @override
  String get errorParse =>
      'Die empfangenen Daten konnten nicht gelesen werden.';

  @override
  String get errorInvalidCredentials =>
      'Benutzername oder Passwort ist falsch.';

  @override
  String get errorUnknown =>
      'Etwas ist schiefgelaufen. Bitte versuche es erneut.';

  @override
  String actionFailed(String reason) {
    return 'Aktion fehlgeschlagen: $reason';
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

    return 'Gesamt: $amountString';
  }

  @override
  String unitPriceTimesQuantity(double price, int quantity) {
    final intl.NumberFormat priceNumberFormat =
        intl.NumberFormat.simpleCurrency(locale: localeName, name: 'USD');
    final String priceString = priceNumberFormat.format(price);

    return '$priceString × $quantity';
  }

  @override
  String get searchHint => 'Produkte suchen';

  @override
  String get recommendedForYou => 'Für dich empfohlen';

  @override
  String get seeAll => 'Alle anzeigen';

  @override
  String get loadMoreFailed =>
      'Weitere Produkte konnten nicht geladen werden. Tippe zum Wiederholen.';

  @override
  String get offlineBanner =>
      'Du bist offline. Es werden die zuletzt geladenen Produkte angezeigt.';

  @override
  String get categoryPhones => 'Handys';

  @override
  String get categoryLaptops => 'Laptops';

  @override
  String get categoryWatches => 'Uhren';

  @override
  String get categoryFashion => 'Mode';

  @override
  String get categoryAccessories => 'Zubehör';

  @override
  String get categoryBeauty => 'Kosmetik';

  @override
  String get productsEmpty => 'Keine Produkte gefunden';

  @override
  String get productDetailTitle => 'Produktdetails';

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

    return 'Auf Lager: $countString';
  }

  @override
  String get productDescription => 'Produktbeschreibung';

  @override
  String get favoriteAdd => 'Zu Favoriten hinzufügen';

  @override
  String get favoriteRemove => 'Aus Favoriten entfernen';

  @override
  String get addToCart => 'In den Warenkorb';

  @override
  String addedToCart(String title) {
    return 'In den Warenkorb gelegt: $title';
  }

  @override
  String get searchPrompt => 'Gib einen Suchbegriff ein';

  @override
  String searchNoResults(String query) {
    return 'Keine Produkte zu „$query“ gefunden';
  }

  @override
  String get cartTitle => 'Warenkorb';

  @override
  String get cartClear => 'Warenkorb leeren';

  @override
  String get cartEmpty => 'Dein Warenkorb ist leer. Schau dich doch mal um!';

  @override
  String get cartCheckout => 'Zur Kasse';

  @override
  String get categoriesTitle => 'Kategorien';

  @override
  String get favoritesTitle => 'Meine Favoriten';

  @override
  String get favoritesEmpty =>
      'Noch keine Favoriten. Tippe auf einer Produktseite auf ♥, um es zu merken.';

  @override
  String favoritesLoadFailed(String reason) {
    return 'Favoriten konnten nicht geladen werden: $reason';
  }

  @override
  String get ordersTitle => 'Meine Bestellungen';

  @override
  String get ordersEmpty =>
      'Noch keine Bestellungen. Wie wäre es mit deiner ersten?';

  @override
  String ordersLoadFailed(String reason) {
    return 'Bestellungen konnten nicht geladen werden: $reason';
  }

  @override
  String get orderPendingCartSync =>
      'Bestellung erstellt, Warenkorb noch nicht synchronisiert';

  @override
  String get orderPendingAddressSave =>
      'Bestellung erstellt, Standardadresse noch nicht gespeichert';

  @override
  String orderNumber(String id) {
    return 'Bestellnr. $id';
  }

  @override
  String orderItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Artikel',
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
  String get orderStatusSubmitted => 'Eingegangen';

  @override
  String get orderStatusPaid => 'Bezahlt';

  @override
  String get orderStatusShipped => 'Versandt';

  @override
  String get checkoutTitle => 'Bestellung bestätigen';

  @override
  String get checkoutEmpty =>
      'Dein Warenkorb ist leer – es gibt nichts zu bezahlen.';

  @override
  String get shippingInfo => 'Lieferinformationen';

  @override
  String get recipientLabel => 'Empfänger';

  @override
  String get recipientRequired => 'Bitte gib den Namen des Empfängers ein';

  @override
  String get phoneLabel => 'Telefonnummer';

  @override
  String get phoneRequired => 'Bitte gib eine Telefonnummer ein';

  @override
  String get phoneInvalid => 'Die Telefonnummer muss 11 Ziffern haben';

  @override
  String get addressLabel => 'Lieferadresse';

  @override
  String get addressRequired => 'Bitte gib die Lieferadresse ein';

  @override
  String get orderItems => 'Artikelübersicht';

  @override
  String get submitOrder => 'Zahlungspflichtig bestellen';

  @override
  String get checkoutNothingToRetry =>
      'Es gibt keine offene Bestellung, die fortgesetzt werden kann.';

  @override
  String get retryCheckout => 'Kauf erneut abschließen';

  @override
  String get orderCreatedCartSyncFailed =>
      'Bestellung erstellt, aber der Warenkorb konnte nicht synchronisiert werden. Tippe auf „Kauf erneut abschließen“.';

  @override
  String get orderPlacedAddressNotSaved =>
      'Bestellung aufgegeben. Die Standardadresse wurde nicht gespeichert – du kannst es auf der Bestellseite erneut versuchen.';

  @override
  String get orderPlaced => 'Bestellung aufgegeben!';

  @override
  String orderFailed(String reason) {
    return 'Bestellung fehlgeschlagen: $reason';
  }

  @override
  String get profileTitle => 'Profil';

  @override
  String get logout => 'Abmelden';

  @override
  String profileLoadFailed(String reason) {
    return 'Profil konnte nicht geladen werden: $reason';
  }

  @override
  String get notLoggedIn => 'Nicht angemeldet';

  @override
  String get language => 'Sprache';

  @override
  String get languageFollowSystem => 'Systemsprache';

  @override
  String get languagePickerTitle => 'Sprache wählen';

  @override
  String get loginTitle => 'Anmelden';

  @override
  String loginTestAccount(String username, String password) {
    return 'Testkonto: $username / $password';
  }

  @override
  String get usernameLabel => 'Benutzername';

  @override
  String get usernameRequired => 'Bitte gib deinen Benutzernamen ein';

  @override
  String get passwordLabel => 'Passwort';

  @override
  String get passwordRequired => 'Bitte gib dein Passwort ein';

  @override
  String get loginSubmit => 'Anmelden';

  @override
  String loginFailed(String reason) {
    return 'Anmeldung fehlgeschlagen: $reason';
  }
}
