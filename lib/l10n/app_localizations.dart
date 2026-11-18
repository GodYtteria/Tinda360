import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fil.dart';

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
    Locale('fil'),
  ];

  /// App name in the task switcher.
  ///
  /// In en, this message translates to:
  /// **'Tinda 360'**
  String get appTitle;

  /// Shown once the on-device database opens.
  ///
  /// In en, this message translates to:
  /// **'Store data is ready'**
  String get homeDatabaseReady;

  /// How many active products the store has.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No products yet} =1{1 product} other{{count} products}}'**
  String homeProductCount(int count);

  /// How many products are at or below their alert level.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing is low on stock} =1{1 product is low on stock} other{{count} products are low on stock}}'**
  String homeLowStockCount(int count);

  /// Shown when the database fails to load.
  ///
  /// In en, this message translates to:
  /// **'The store data could not be opened.'**
  String get homeLoadFailed;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get commonSwitch;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @splashPreparingAi.
  ///
  /// In en, this message translates to:
  /// **'Preparing AI...'**
  String get splashPreparingAi;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Smart POS with AI, even offline'**
  String get splashTagline;

  /// No description provided for @onboardingStep1Title.
  ///
  /// In en, this message translates to:
  /// **'What is your store\'s name?'**
  String get onboardingStep1Title;

  /// No description provided for @onboardingStep1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'This appears on your reports and receipts.'**
  String get onboardingStep1Subtitle;

  /// No description provided for @onboardingStoreNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Store name'**
  String get onboardingStoreNameLabel;

  /// No description provided for @onboardingStoreNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Aling Nena\'s Store'**
  String get onboardingStoreNameHint;

  /// No description provided for @onboardingStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Do you have a backup?'**
  String get onboardingStep2Title;

  /// No description provided for @onboardingStep2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'You can start fresh or restore from Google Drive.'**
  String get onboardingStep2Subtitle;

  /// No description provided for @onboardingNewStoreTitle.
  ///
  /// In en, this message translates to:
  /// **'I am a new store'**
  String get onboardingNewStoreTitle;

  /// No description provided for @onboardingNewStoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start right away, offline on your phone.'**
  String get onboardingNewStoreSubtitle;

  /// No description provided for @onboardingSampleItemsToggle.
  ///
  /// In en, this message translates to:
  /// **'Add sample products to try right away'**
  String get onboardingSampleItemsToggle;

  /// No description provided for @onboardingRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from Google'**
  String get onboardingRestoreTitle;

  /// No description provided for @onboardingRestoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bring back products, sales, and utang.'**
  String get onboardingRestoreSubtitle;

  /// No description provided for @onboardingGoogleButton.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get onboardingGoogleButton;

  /// No description provided for @onboardingRestoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google Drive restore is not connected yet. You can start fresh and back up later.'**
  String get onboardingRestoreUnavailable;

  /// No description provided for @navSales.
  ///
  /// In en, this message translates to:
  /// **'POS'**
  String get navSales;

  /// No description provided for @navInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get navInventory;

  /// No description provided for @navUtang.
  ///
  /// In en, this message translates to:
  /// **'Utang'**
  String get navUtang;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @posSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search product or barcode...'**
  String get posSearchHint;

  /// No description provided for @posScanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get posScanBarcode;

  /// No description provided for @posOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get posOpenSettings;

  /// No description provided for @posGreeting.
  ///
  /// In en, this message translates to:
  /// **'Magandang araw! Ready to sell. Tap any product to add to cart.'**
  String get posGreeting;

  /// No description provided for @posGreetingDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss greeting'**
  String get posGreetingDismiss;

  /// No description provided for @posAddToCart.
  ///
  /// In en, this message translates to:
  /// **'Add {name}'**
  String posAddToCart(String name);

  /// No description provided for @posRemoveFromCart.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String posRemoveFromCart(String name);

  /// No description provided for @posStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Stock {qty}'**
  String posStockLabel(String qty);

  /// No description provided for @posOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'No more stock for {name}.'**
  String posOutOfStock(String name);

  /// No description provided for @posLowStockBadge.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get posLowStockBadge;

  /// No description provided for @posOutOfStockBadge.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get posOutOfStockBadge;

  /// No description provided for @checkoutExactAmountChip.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get checkoutExactAmountChip;

  /// No description provided for @posBackupStaleTitle.
  ///
  /// In en, this message translates to:
  /// **'No backup in the last 7 days'**
  String get posBackupStaleTitle;

  /// No description provided for @posBackupNeverTitle.
  ///
  /// In en, this message translates to:
  /// **'Back up your data so it is not lost'**
  String get posBackupNeverTitle;

  /// No description provided for @posBackupWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Tap to open Settings and back up now.'**
  String get posBackupWarningBody;

  /// No description provided for @posQuantityMode.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get posQuantityMode;

  /// No description provided for @posAmountMode.
  ///
  /// In en, this message translates to:
  /// **'Amount (₱)'**
  String get posAmountMode;

  /// No description provided for @posAmountEquals.
  ///
  /// In en, this message translates to:
  /// **'= {quantity}'**
  String posAmountEquals(String quantity);

  /// No description provided for @posCartItems.
  ///
  /// In en, this message translates to:
  /// **'Cart · {count, plural, =1{1 item} other{{count} items}}'**
  String posCartItems(int count);

  /// No description provided for @posPayButton.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get posPayButton;

  /// No description provided for @posEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get posEmptyTitle;

  /// No description provided for @posEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add products in Inventory to start selling.'**
  String get posEmptyBody;

  /// No description provided for @posStorageFullTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone storage is almost full'**
  String get posStorageFullTitle;

  /// No description provided for @posStorageFullBody.
  ///
  /// In en, this message translates to:
  /// **'Your sales still continue. Free up space soon so data stays safe.'**
  String get posStorageFullBody;

  /// No description provided for @checkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkoutTitle;

  /// No description provided for @checkoutTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get checkoutTotalLabel;

  /// No description provided for @checkoutMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get checkoutMethodCash;

  /// No description provided for @checkoutMethodEwallet.
  ///
  /// In en, this message translates to:
  /// **'E-wallet'**
  String get checkoutMethodEwallet;

  /// No description provided for @checkoutMethodUtang.
  ///
  /// In en, this message translates to:
  /// **'Utang'**
  String get checkoutMethodUtang;

  /// No description provided for @checkoutTenderedLabel.
  ///
  /// In en, this message translates to:
  /// **'Cash received'**
  String get checkoutTenderedLabel;

  /// No description provided for @checkoutChangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get checkoutChangeLabel;

  /// No description provided for @checkoutPaidNowLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid now (₱, optional)'**
  String get checkoutPaidNowLabel;

  /// No description provided for @checkoutPaidNowRemaining.
  ///
  /// In en, this message translates to:
  /// **'Utang for this sale: {amount}'**
  String checkoutPaidNowRemaining(String amount);

  /// No description provided for @checkoutPaidNowInvalid.
  ///
  /// In en, this message translates to:
  /// **'Paid now must be from ₱0 up to the total.'**
  String get checkoutPaidNowInvalid;

  /// No description provided for @checkoutPriceDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Price for {product}'**
  String checkoutPriceDialogTitle(String product);

  /// No description provided for @checkoutPriceNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal price: {price}'**
  String checkoutPriceNormal(String price);

  /// No description provided for @checkoutPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price per unit this sale (₱)'**
  String get checkoutPriceLabel;

  /// No description provided for @checkoutPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a price of ₱0 or more.'**
  String get checkoutPriceInvalid;

  /// No description provided for @checkoutPriceReset.
  ///
  /// In en, this message translates to:
  /// **'Back to normal price'**
  String get checkoutPriceReset;

  /// No description provided for @failureSalePaidNowInvalid.
  ///
  /// In en, this message translates to:
  /// **'Paid now must be from ₱0 up to the total.'**
  String get failureSalePaidNowInvalid;

  /// No description provided for @failureSalePriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Price cannot be negative.'**
  String get failureSalePriceInvalid;

  /// No description provided for @receiptNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Receipt no.'**
  String get receiptNumberLabel;

  /// No description provided for @receiptSukiLabel.
  ///
  /// In en, this message translates to:
  /// **'Suki'**
  String get receiptSukiLabel;

  /// No description provided for @receiptReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Ref'**
  String get receiptReferenceLabel;

  /// No description provided for @checkoutEwalletRefLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference number (optional)'**
  String get checkoutEwalletRefLabel;

  /// No description provided for @checkoutEwalletRefHint.
  ///
  /// In en, this message translates to:
  /// **'Last 4 digits or ref no.'**
  String get checkoutEwalletRefHint;

  /// No description provided for @checkoutEwalletReminder.
  ///
  /// In en, this message translates to:
  /// **'Make sure the payment is received before completing the sale.'**
  String get checkoutEwalletReminder;

  /// No description provided for @checkoutSelectSuki.
  ///
  /// In en, this message translates to:
  /// **'Choose suki'**
  String get checkoutSelectSuki;

  /// No description provided for @checkoutNoSuki.
  ///
  /// In en, this message translates to:
  /// **'No suki added yet. Add a suki in Utang first.'**
  String get checkoutNoSuki;

  /// No description provided for @checkoutUtangNote.
  ///
  /// In en, this message translates to:
  /// **'The total will be added to the suki\'s balance.'**
  String get checkoutUtangNote;

  /// No description provided for @checkoutFinishSale.
  ///
  /// In en, this message translates to:
  /// **'Complete sale'**
  String get checkoutFinishSale;

  /// No description provided for @checkoutRecordUtang.
  ///
  /// In en, this message translates to:
  /// **'Record as utang'**
  String get checkoutRecordUtang;

  /// No description provided for @saleDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Sale complete!'**
  String get saleDoneTitle;

  /// No description provided for @saleDoneTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get saleDoneTotal;

  /// No description provided for @saleDonePaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get saleDonePaid;

  /// No description provided for @saleDoneChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get saleDoneChange;

  /// No description provided for @saleDoneNewSale.
  ///
  /// In en, this message translates to:
  /// **'New sale'**
  String get saleDoneNewSale;

  /// No description provided for @saleDoneShareReceipt.
  ///
  /// In en, this message translates to:
  /// **'Share receipt'**
  String get saleDoneShareReceipt;

  /// No description provided for @saleDoneShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open sharing. Try again.'**
  String get saleDoneShareFailed;

  /// No description provided for @saleDoneReceiptCopied.
  ///
  /// In en, this message translates to:
  /// **'Receipt summary ready to share.'**
  String get saleDoneReceiptCopied;

  /// No description provided for @inventoryLowFilter.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get inventoryLowFilter;

  /// No description provided for @inventoryAddProduct.
  ///
  /// In en, this message translates to:
  /// **'+ Product'**
  String get inventoryAddProduct;

  /// No description provided for @inventoryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get inventoryEmptyTitle;

  /// No description provided for @inventoryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap + Product to add your first item.'**
  String get inventoryEmptyBody;

  /// No description provided for @inventoryFilterEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching products'**
  String get inventoryFilterEmptyTitle;

  /// No description provided for @inventoryFilterEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or filter.'**
  String get inventoryFilterEmptyBody;

  /// No description provided for @inventorySummary.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{1 product} other{{total} products}} · {low} low'**
  String inventorySummary(int total, int low);

  /// No description provided for @productSheetAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get productSheetAddTitle;

  /// No description provided for @productSheetEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get productSheetEditTitle;

  /// No description provided for @productNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get productNameLabel;

  /// No description provided for @productNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Lucky Me Pancit Canton'**
  String get productNameHint;

  /// No description provided for @productPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Selling price (₱)'**
  String get productPriceLabel;

  /// No description provided for @productCostLabel.
  ///
  /// In en, this message translates to:
  /// **'Cost / puhunan (₱)'**
  String get productCostLabel;

  /// No description provided for @productNoCountSwitch.
  ///
  /// In en, this message translates to:
  /// **'Don\'t count stock'**
  String get productNoCountSwitch;

  /// No description provided for @productNoCountHint.
  ///
  /// In en, this message translates to:
  /// **'For load, tingi and other items you don\'t count.'**
  String get productNoCountHint;

  /// No description provided for @productExpiryLabel.
  ///
  /// In en, this message translates to:
  /// **'Expiry date (optional)'**
  String get productExpiryLabel;

  /// No description provided for @productExpiryClear.
  ///
  /// In en, this message translates to:
  /// **'Clear expiry date'**
  String get productExpiryClear;

  /// No description provided for @productDuplicateNameWarning.
  ///
  /// In en, this message translates to:
  /// **'A product with the same name already exists.'**
  String get productDuplicateNameWarning;

  /// No description provided for @productPriceZeroWarning.
  ///
  /// In en, this message translates to:
  /// **'Price is 0. Is that right?'**
  String get productPriceZeroWarning;

  /// No description provided for @inventoryNoCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Not counted'**
  String get inventoryNoCountLabel;

  /// No description provided for @inventoryExpiryDaysBadge.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Expires today} =1{Expires in 1 day} other{Expires in {count} days}}'**
  String inventoryExpiryDaysBadge(int count);

  /// No description provided for @inventoryExpiredBadge.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get inventoryExpiredBadge;

  /// No description provided for @inventoryExpiringFilter.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get inventoryExpiringFilter;

  /// No description provided for @inventoryShareShoppingList.
  ///
  /// In en, this message translates to:
  /// **'Share shopping list'**
  String get inventoryShareShoppingList;

  /// No description provided for @shoppingListHeader.
  ///
  /// In en, this message translates to:
  /// **'Shopping list:'**
  String get shoppingListHeader;

  /// No description provided for @shoppingListLine.
  ///
  /// In en, this message translates to:
  /// **'- {name}: buy {amount} {unit}'**
  String shoppingListLine(String name, String amount, String unit);

  /// No description provided for @productRestockCostLabel.
  ///
  /// In en, this message translates to:
  /// **'New cost per unit (₱), optional'**
  String get productRestockCostLabel;

  /// No description provided for @productStockHistoryButton.
  ///
  /// In en, this message translates to:
  /// **'Stock history'**
  String get productStockHistoryButton;

  /// No description provided for @stockHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock history'**
  String get stockHistoryTitle;

  /// No description provided for @stockHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stock changes yet.'**
  String get stockHistoryEmpty;

  /// No description provided for @stockHistoryAfter.
  ///
  /// In en, this message translates to:
  /// **'Stock after: {stock}'**
  String stockHistoryAfter(String stock);

  /// No description provided for @stockReasonInitial.
  ///
  /// In en, this message translates to:
  /// **'Initial stock'**
  String get stockReasonInitial;

  /// No description provided for @stockReasonRestock.
  ///
  /// In en, this message translates to:
  /// **'Restock'**
  String get stockReasonRestock;

  /// No description provided for @stockReasonAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get stockReasonAdjust;

  /// No description provided for @stockReasonReturn.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get stockReasonReturn;

  /// No description provided for @receiptRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get receiptRefunded;

  /// No description provided for @receiptNetTotal.
  ///
  /// In en, this message translates to:
  /// **'Net total'**
  String get receiptNetTotal;

  /// No description provided for @checkoutCreditNearTitle.
  ///
  /// In en, this message translates to:
  /// **'Utang near credit limit'**
  String get checkoutCreditNearTitle;

  /// No description provided for @checkoutCreditNearBody.
  ///
  /// In en, this message translates to:
  /// **'{name} already has {balance} unpaid utang (credit limit: {limit}).'**
  String checkoutCreditNearBody(String name, String balance, String limit);

  /// No description provided for @reportsExportCsvError.
  ///
  /// In en, this message translates to:
  /// **'Could not export the CSV file.'**
  String get reportsExportCsvError;

  /// No description provided for @ledgerDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this line?'**
  String get ledgerDeleteConfirmTitle;

  /// No description provided for @ledgerDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{kind} {amount} on {date}. The line stays in the history as deleted and the balance is fixed.'**
  String ledgerDeleteConfirmBody(String kind, String amount, String date);

  /// No description provided for @ledgerDeleteReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get ledgerDeleteReasonLabel;

  /// No description provided for @ledgerDeleteConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete line'**
  String get ledgerDeleteConfirmAction;

  /// No description provided for @ledgerDeleteDone.
  ///
  /// In en, this message translates to:
  /// **'Line deleted.'**
  String get ledgerDeleteDone;

  /// No description provided for @ledgerDeletedWithReason.
  ///
  /// In en, this message translates to:
  /// **'Deleted: {reason}'**
  String ledgerDeletedWithReason(String reason);

  /// No description provided for @ledgerDeletedNoReason.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get ledgerDeletedNoReason;

  /// No description provided for @ledgerNotDeletableHint.
  ///
  /// In en, this message translates to:
  /// **'From a sale. Void the sale instead.'**
  String get ledgerNotDeletableHint;

  /// No description provided for @failureLedgerEntryNotFound.
  ///
  /// In en, this message translates to:
  /// **'This line was not found.'**
  String get failureLedgerEntryNotFound;

  /// No description provided for @failureLedgerEntryAlreadyDeleted.
  ///
  /// In en, this message translates to:
  /// **'This line is already deleted.'**
  String get failureLedgerEntryAlreadyDeleted;

  /// No description provided for @failureLedgerEntryNotDeletable.
  ///
  /// In en, this message translates to:
  /// **'This line cannot be deleted here. Void the sale instead.'**
  String get failureLedgerEntryNotDeletable;

  /// No description provided for @failureLedgerDeleteWouldGoNegative.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete this interest. Payments already went over the balance.'**
  String get failureLedgerDeleteWouldGoNegative;

  /// No description provided for @checkoutInterestLabel.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get checkoutInterestLabel;

  /// No description provided for @checkoutInterestPrompt.
  ///
  /// In en, this message translates to:
  /// **'Tutubuan ba? Optional.'**
  String get checkoutInterestPrompt;

  /// No description provided for @checkoutInterestPercentInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a percent from 0.1 to 50.0, for example 5 or 2.5.'**
  String get checkoutInterestPercentInvalid;

  /// No description provided for @checkoutInterestAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid peso amount above zero.'**
  String get checkoutInterestAmountInvalid;

  /// No description provided for @checkoutInterestTooMuch.
  ///
  /// In en, this message translates to:
  /// **'Interest cannot be more than the utang.'**
  String get checkoutInterestTooMuch;

  /// No description provided for @checkoutInterestPreview.
  ///
  /// In en, this message translates to:
  /// **'Utang {utang} + interest {interest} = {total}'**
  String checkoutInterestPreview(String utang, String interest, String total);

  /// No description provided for @receiptInterest.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get receiptInterest;

  /// No description provided for @failureSaleInterestInvalid.
  ///
  /// In en, this message translates to:
  /// **'Interest must be more than zero, and only for utang with a suki.'**
  String get failureSaleInterestInvalid;

  /// No description provided for @productUtangPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Utang price (₱, optional)'**
  String get productUtangPriceLabel;

  /// No description provided for @checkoutUtangPriceTag.
  ///
  /// In en, this message translates to:
  /// **'Utang price'**
  String get checkoutUtangPriceTag;

  /// No description provided for @failureCustomerInterestAmountChanged.
  ///
  /// In en, this message translates to:
  /// **'The utang changed, so the interest changed too. Please check and try again.'**
  String get failureCustomerInterestAmountChanged;

  /// No description provided for @checkoutShortfallPrompt.
  ///
  /// In en, this message translates to:
  /// **'Payment is short. Put the missing {amount} on utang? Pick a suki below.'**
  String checkoutShortfallPrompt(String amount);

  /// No description provided for @yumiChipLowStock.
  ///
  /// In en, this message translates to:
  /// **'What is low on stock?'**
  String get yumiChipLowStock;

  /// No description provided for @yumiChipSalesToday.
  ///
  /// In en, this message translates to:
  /// **'How are sales today?'**
  String get yumiChipSalesToday;

  /// No description provided for @yumiChipProductCount.
  ///
  /// In en, this message translates to:
  /// **'How many products do I have?'**
  String get yumiChipProductCount;

  /// No description provided for @yumiChipSlowMoving.
  ///
  /// In en, this message translates to:
  /// **'Slow-moving products?'**
  String get yumiChipSlowMoving;

  /// No description provided for @yumiChipWhoHasUtang.
  ///
  /// In en, this message translates to:
  /// **'Who has utang?'**
  String get yumiChipWhoHasUtang;

  /// No description provided for @yumiChipUtangRisk.
  ///
  /// In en, this message translates to:
  /// **'Utang risk?'**
  String get yumiChipUtangRisk;

  /// No description provided for @yumiChipExpensesWeek.
  ///
  /// In en, this message translates to:
  /// **'Expenses this week?'**
  String get yumiChipExpensesWeek;

  /// No description provided for @yumiChipCompareYesterday.
  ///
  /// In en, this message translates to:
  /// **'Compare with yesterday'**
  String get yumiChipCompareYesterday;

  /// No description provided for @yumiChipWhatCanYouDo.
  ///
  /// In en, this message translates to:
  /// **'What can you do?'**
  String get yumiChipWhatCanYouDo;

  /// No description provided for @yumiHintPos.
  ///
  /// In en, this message translates to:
  /// **'You\'re on Sales. Ask me what is low on stock or how today is going.'**
  String get yumiHintPos;

  /// No description provided for @yumiHintInventory.
  ///
  /// In en, this message translates to:
  /// **'You\'re on Inventory. Ask me what is low or slow-moving.'**
  String get yumiHintInventory;

  /// No description provided for @yumiHintUtang.
  ///
  /// In en, this message translates to:
  /// **'You\'re on Utang. Ask me who owes and how much.'**
  String get yumiHintUtang;

  /// No description provided for @yumiHintReports.
  ///
  /// In en, this message translates to:
  /// **'You\'re on Reports. Ask me about sales, expenses, or yesterday.'**
  String get yumiHintReports;

  /// No description provided for @yumiHintSettings.
  ///
  /// In en, this message translates to:
  /// **'You\'re on Settings. Ask me what I can do.'**
  String get yumiHintSettings;

  /// No description provided for @sukiTuboLabel.
  ///
  /// In en, this message translates to:
  /// **'Interest % (optional)'**
  String get sukiTuboLabel;

  /// No description provided for @sukiTuboHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 5 or 2.5'**
  String get sukiTuboHint;

  /// No description provided for @sukiTuboInvalid.
  ///
  /// In en, this message translates to:
  /// **'Interest must be from 0.1 to 50.0 percent.'**
  String get sukiTuboInvalid;

  /// No description provided for @ledgerKindTubo.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get ledgerKindTubo;

  /// No description provided for @ledgerAddTubo.
  ///
  /// In en, this message translates to:
  /// **'Add interest'**
  String get ledgerAddTubo;

  /// No description provided for @ledgerTuboConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Add interest?'**
  String get ledgerTuboConfirmTitle;

  /// No description provided for @ledgerTuboConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{balance} + {percent}% = {amount} interest'**
  String ledgerTuboConfirmBody(String balance, String percent, String amount);

  /// No description provided for @ledgerTuboConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Add interest'**
  String get ledgerTuboConfirmAction;

  /// No description provided for @ledgerTuboAdded.
  ///
  /// In en, this message translates to:
  /// **'Interest of {amount} added.'**
  String ledgerTuboAdded(String amount);

  /// No description provided for @ledgerReminderTuboMessage.
  ///
  /// In en, this message translates to:
  /// **'Hi {customerName}! Friendly reminder from {storeName}: Utang {utang} + interest {tubo} = {total}. Thank you!'**
  String ledgerReminderTuboMessage(
    String customerName,
    String storeName,
    String utang,
    String tubo,
    String total,
  );

  /// No description provided for @failureCustomerInterestRateNotSet.
  ///
  /// In en, this message translates to:
  /// **'This suki has no interest rate set.'**
  String get failureCustomerInterestRateNotSet;

  /// No description provided for @failureCustomerInterestNoBalance.
  ///
  /// In en, this message translates to:
  /// **'No balance to add interest to.'**
  String get failureCustomerInterestNoBalance;

  /// No description provided for @stockReasonSale.
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get stockReasonSale;

  /// No description provided for @reportPdfMetricHeader.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get reportPdfMetricHeader;

  /// No description provided for @reportPdfValueHeader.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get reportPdfValueHeader;

  /// No description provided for @reportPdfProductHeader.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get reportPdfProductHeader;

  /// No description provided for @reportPdfQuantitySoldHeader.
  ///
  /// In en, this message translates to:
  /// **'Qty Sold'**
  String get reportPdfQuantitySoldHeader;

  /// No description provided for @reportPdfRevenueHeader.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get reportPdfRevenueHeader;

  /// No description provided for @reportPdfPreparedBy.
  ///
  /// In en, this message translates to:
  /// **'{storeName} - Prepared by Store Owner'**
  String reportPdfPreparedBy(String storeName);

  /// No description provided for @sukiEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get sukiEditAction;

  /// No description provided for @sukiDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sukiDeleteAction;

  /// No description provided for @sukiEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit suki'**
  String get sukiEditTitle;

  /// No description provided for @sukiSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get sukiSaveChanges;

  /// No description provided for @sukiDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete suki?'**
  String get sukiDeleteConfirmTitle;

  /// No description provided for @sukiDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be removed from your suki list. This only works when the balance is zero.'**
  String sukiDeleteConfirmBody(String name);

  /// No description provided for @failureCustomerHasBalance.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete a suki who still has utang.'**
  String get failureCustomerHasBalance;

  /// No description provided for @ledgerShareReminder.
  ///
  /// In en, this message translates to:
  /// **'Share reminder'**
  String get ledgerShareReminder;

  /// No description provided for @ledgerCopyReminder.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get ledgerCopyReminder;

  /// No description provided for @ledgerEmptyEntries.
  ///
  /// In en, this message translates to:
  /// **'No ledger entries yet.'**
  String get ledgerEmptyEntries;

  /// No description provided for @ledgerKindUtang.
  ///
  /// In en, this message translates to:
  /// **'Utang'**
  String get ledgerKindUtang;

  /// No description provided for @ledgerKindPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get ledgerKindPayment;

  /// No description provided for @ledgerReminderDefaultStore.
  ///
  /// In en, this message translates to:
  /// **'our store'**
  String get ledgerReminderDefaultStore;

  /// No description provided for @ledgerReminderMessage.
  ///
  /// In en, this message translates to:
  /// **'Hi {customerName}! Friendly reminder from {storeName}: your utang balance is {balance}. Thank you!'**
  String ledgerReminderMessage(
    String customerName,
    String storeName,
    String balance,
  );

  /// No description provided for @inventoryCostSummary.
  ///
  /// In en, this message translates to:
  /// **'Cost {amount}'**
  String inventoryCostSummary(String amount);

  /// No description provided for @productProfitPerSale.
  ///
  /// In en, this message translates to:
  /// **'Profit per sale: {amount}'**
  String productProfitPerSale(String amount);

  /// No description provided for @productUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get productUnitLabel;

  /// No description provided for @productCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category (optional)'**
  String get productCategoryLabel;

  /// No description provided for @productInitialStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Starting stock'**
  String get productInitialStockLabel;

  /// No description provided for @productAdjustStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Adjust stock'**
  String get productAdjustStockLabel;

  /// No description provided for @productCurrentStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Current stock: {qty}'**
  String productCurrentStockLabel(String qty);

  /// No description provided for @productLowStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Low-stock alert at'**
  String get productLowStockLabel;

  /// No description provided for @productBarcodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Barcode (optional)'**
  String get productBarcodeLabel;

  /// No description provided for @productDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete product'**
  String get productDeleteButton;

  /// No description provided for @productDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this product from active items?'**
  String get productDeleteConfirm;

  /// No description provided for @utangTitle.
  ///
  /// In en, this message translates to:
  /// **'Utang'**
  String get utangTitle;

  /// No description provided for @utangTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total utang'**
  String get utangTotalLabel;

  /// No description provided for @utangSukiCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No suki} =1{1 suki} other{{count} suki}}'**
  String utangSukiCount(int count);

  /// No description provided for @utangSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search suki...'**
  String get utangSearchHint;

  /// No description provided for @utangPayButton.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get utangPayButton;

  /// No description provided for @utangAddSuki.
  ///
  /// In en, this message translates to:
  /// **'+ Suki'**
  String get utangAddSuki;

  /// No description provided for @utangBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get utangBalanceLabel;

  /// No description provided for @utangOverLimit.
  ///
  /// In en, this message translates to:
  /// **'Over limit'**
  String get utangOverLimit;

  /// No description provided for @utangEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No utang right now'**
  String get utangEmptyTitle;

  /// No description provided for @utangEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Suki balances will show up here.'**
  String get utangEmptyBody;

  /// No description provided for @utangPayTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay utang'**
  String get utangPayTitle;

  /// No description provided for @utangNewSukiTitle.
  ///
  /// In en, this message translates to:
  /// **'New suki'**
  String get utangNewSukiTitle;

  /// No description provided for @utangCurrentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current balance'**
  String get utangCurrentBalance;

  /// No description provided for @utangAgeDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String utangAgeDays(int count);

  /// No description provided for @utangExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export utang (CSV)'**
  String get utangExportCsv;

  /// No description provided for @checkoutCreditLimitExceeded.
  ///
  /// In en, this message translates to:
  /// **'Over the utang limit ({limit})'**
  String checkoutCreditLimitExceeded(String limit);

  /// No description provided for @checkoutCreditLimitOverride.
  ///
  /// In en, this message translates to:
  /// **'Owner approval'**
  String get checkoutCreditLimitOverride;

  /// No description provided for @utangFullPayment.
  ///
  /// In en, this message translates to:
  /// **'Full payment'**
  String get utangFullPayment;

  /// No description provided for @utangPartialPayment.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get utangPartialPayment;

  /// No description provided for @utangPaymentAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment amount (₱)'**
  String get utangPaymentAmountLabel;

  /// No description provided for @utangNewBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'New balance'**
  String get utangNewBalanceLabel;

  /// No description provided for @utangRecordPayment.
  ///
  /// In en, this message translates to:
  /// **'Save payment'**
  String get utangRecordPayment;

  /// No description provided for @utangSukiNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Suki name'**
  String get utangSukiNameLabel;

  /// No description provided for @utangSukiPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number (optional)'**
  String get utangSukiPhoneLabel;

  /// No description provided for @utangSukiLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Utang limit (optional)'**
  String get utangSukiLimitLabel;

  /// No description provided for @utangSaveSuki.
  ///
  /// In en, this message translates to:
  /// **'Save suki'**
  String get utangSaveSuki;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @reportsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get reportsToday;

  /// No description provided for @reportsWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get reportsWeek;

  /// No description provided for @reportsMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get reportsMonth;

  /// No description provided for @reportsSalesCard.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get reportsSalesCard;

  /// No description provided for @reportsProfitCard.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get reportsProfitCard;

  /// No description provided for @reportsTransactionsCard.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get reportsTransactionsCard;

  /// No description provided for @reportsNewUtangCard.
  ///
  /// In en, this message translates to:
  /// **'Unpaid utang'**
  String get reportsNewUtangCard;

  /// No description provided for @reportsChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales trend'**
  String get reportsChartTitle;

  /// No description provided for @reportsChartTitlePeriod.
  ///
  /// In en, this message translates to:
  /// **'Sales trend · {period}'**
  String reportsChartTitlePeriod(String period);

  /// No description provided for @reportsTopProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'Top 3 products'**
  String get reportsTopProductsTitle;

  /// No description provided for @reportsTopProductSold.
  ///
  /// In en, this message translates to:
  /// **'{qty} sold · {amount}'**
  String reportsTopProductSold(String qty, String amount);

  /// No description provided for @reportsAskAi.
  ///
  /// In en, this message translates to:
  /// **'Ask Smart Store Assistant about this report'**
  String get reportsAskAi;

  /// No description provided for @reportsExportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF report'**
  String get reportsExportPdf;

  /// No description provided for @reportsExportPdfError.
  ///
  /// In en, this message translates to:
  /// **'Could not generate PDF report.'**
  String get reportsExportPdfError;

  /// No description provided for @reportsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No sales in this period'**
  String get reportsEmptyTitle;

  /// No description provided for @reportsEmptyTitlePeriod.
  ///
  /// In en, this message translates to:
  /// **'No sales ({period})'**
  String reportsEmptyTitlePeriod(String period);

  /// No description provided for @reportsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Completed sales will appear here.'**
  String get reportsEmptyBody;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Store Assistant'**
  String get chatTitle;

  /// No description provided for @chatStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'On-device · Offline'**
  String get chatStatusOffline;

  /// No description provided for @chatStatusThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get chatStatusThinking;

  /// No description provided for @chatThinkingBubble.
  ///
  /// In en, this message translates to:
  /// **'Looking at your store data...'**
  String get chatThinkingBubble;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about sales, stock, or utang...'**
  String get chatInputHint;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get chatVoice;

  /// No description provided for @chatSourcePrefix.
  ///
  /// In en, this message translates to:
  /// **'From: {source}'**
  String chatSourcePrefix(String source);

  /// No description provided for @chatOpenTindaAi.
  ///
  /// In en, this message translates to:
  /// **'Open Smart Store Assistant'**
  String get chatOpenTindaAi;

  /// No description provided for @chatSuggestionSales.
  ///
  /// In en, this message translates to:
  /// **'How are sales today?'**
  String get chatSuggestionSales;

  /// No description provided for @chatSuggestionLowStock.
  ///
  /// In en, this message translates to:
  /// **'What is low on stock?'**
  String get chatSuggestionLowStock;

  /// No description provided for @chatSuggestionUtang.
  ///
  /// In en, this message translates to:
  /// **'Who has utang?'**
  String get chatSuggestionUtang;

  /// No description provided for @chatModelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Smart Store Assistant model is offline fallback mode. Your sales continue normally.'**
  String get chatModelUnavailable;

  /// No description provided for @chatErrorReply.
  ///
  /// In en, this message translates to:
  /// **'Could not read store data right now. Your sales still continue normally.'**
  String get chatErrorReply;

  /// No description provided for @chatSourceSales.
  ///
  /// In en, this message translates to:
  /// **'Sales · On-device DB'**
  String get chatSourceSales;

  /// No description provided for @chatSourceInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory · On-device DB'**
  String get chatSourceInventory;

  /// No description provided for @chatSourceUtang.
  ///
  /// In en, this message translates to:
  /// **'Utang Ledger · On-device DB'**
  String get chatSourceUtang;

  /// No description provided for @chatSourceSummary.
  ///
  /// In en, this message translates to:
  /// **'Store Summary · On-device DB'**
  String get chatSourceSummary;

  /// No description provided for @chatReplySalesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sales today yet. Once you record a sale, I will show total sales and profit here.'**
  String get chatReplySalesEmpty;

  /// No description provided for @chatReplySalesSummary.
  ///
  /// In en, this message translates to:
  /// **'Today has {count} sales: {revenue} total sales and {profit} profit.'**
  String chatReplySalesSummary(int count, String revenue, String profit);

  /// No description provided for @chatReplyLowStockNone.
  ///
  /// In en, this message translates to:
  /// **'All {count} products are stocked well — nothing is low right now.'**
  String chatReplyLowStockNone(int count);

  /// No description provided for @chatReplyLowStockFound.
  ///
  /// In en, this message translates to:
  /// **'{count} products are low on stock: {names}.'**
  String chatReplyLowStockFound(int count, String names);

  /// No description provided for @chatReplyUtangNone.
  ///
  /// In en, this message translates to:
  /// **'No suki has utang right now.'**
  String get chatReplyUtangNone;

  /// No description provided for @chatReplyUtangSummary.
  ///
  /// In en, this message translates to:
  /// **'Total utang: {total} across {count} suki. Highest: {topNames}.'**
  String chatReplyUtangSummary(String total, int count, String topNames);

  /// No description provided for @chatReplyOverview.
  ///
  /// In en, this message translates to:
  /// **'Store summary: {revenue} sales today ({count} transactions), {lowCount} low on stock, and {totalUtang} total utang.'**
  String chatReplyOverview(
    String revenue,
    int count,
    int lowCount,
    String totalUtang,
  );

  /// No description provided for @posScanUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable or permission denied. Enter the barcode manually below.'**
  String get posScanUnavailable;

  /// No description provided for @posScanTorchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Toggle flashlight'**
  String get posScanTorchTooltip;

  /// No description provided for @scannerManualHint.
  ///
  /// In en, this message translates to:
  /// **'Or type barcode manually...'**
  String get scannerManualHint;

  /// No description provided for @scannerUseCode.
  ///
  /// In en, this message translates to:
  /// **'Use barcode'**
  String get scannerUseCode;

  /// No description provided for @scannerProductNotFound.
  ///
  /// In en, this message translates to:
  /// **'No product matches barcode {code}.'**
  String scannerProductNotFound(String code);

  /// No description provided for @productStockDecrement.
  ///
  /// In en, this message translates to:
  /// **'Decrease starting stock'**
  String get productStockDecrement;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionBackup.
  ///
  /// In en, this message translates to:
  /// **'BACKUP'**
  String get settingsSectionBackup;

  /// No description provided for @settingsSectionAi.
  ///
  /// In en, this message translates to:
  /// **'SMART STORE ASSISTANT'**
  String get settingsSectionAi;

  /// No description provided for @settingsSectionStore.
  ///
  /// In en, this message translates to:
  /// **'STORE'**
  String get settingsSectionStore;

  /// No description provided for @settingsSectionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY'**
  String get settingsSectionPrivacy;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get settingsSectionAbout;

  /// No description provided for @settingsSectionStorage.
  ///
  /// In en, this message translates to:
  /// **'STORAGE & DATA'**
  String get settingsSectionStorage;

  /// No description provided for @settingsStorageSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Database size'**
  String get settingsStorageSizeLabel;

  /// No description provided for @settingsCompactButton.
  ///
  /// In en, this message translates to:
  /// **'Compact storage'**
  String get settingsCompactButton;

  /// No description provided for @settingsCompactDone.
  ///
  /// In en, this message translates to:
  /// **'Database compacted ({size}).'**
  String settingsCompactDone(String size);

  /// No description provided for @settingsNoBackupWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'No Google Drive backup yet'**
  String get settingsNoBackupWarningTitle;

  /// No description provided for @settingsNoBackupWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Data will be lost if you Clear Data in Android Settings or uninstall. Connect Google above to keep it safe.'**
  String get settingsNoBackupWarningBody;

  /// No description provided for @settingsBackupNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected yet'**
  String get settingsBackupNotConnected;

  /// No description provided for @settingsBackupConnecting.
  ///
  /// In en, this message translates to:
  /// **'Choosing account...'**
  String get settingsBackupConnecting;

  /// No description provided for @settingsBackupConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get settingsBackupConnected;

  /// No description provided for @settingsBackupChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Which data should we keep?'**
  String get settingsBackupChooseTitle;

  /// No description provided for @settingsBackupUsePhone.
  ///
  /// In en, this message translates to:
  /// **'Use data on this phone'**
  String get settingsBackupUsePhone;

  /// No description provided for @settingsBackupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get settingsBackupRestore;

  /// No description provided for @settingsBackupSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get settingsBackupSyncNow;

  /// No description provided for @settingsBackupDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Google'**
  String get settingsBackupDisconnect;

  /// No description provided for @settingsBackupLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {time}'**
  String settingsBackupLastSync(String time);

  /// No description provided for @settingsBackupJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get settingsBackupJustNow;

  /// No description provided for @settingsBackupWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Sync on Wi-Fi only'**
  String get settingsBackupWifiOnly;

  /// No description provided for @settingsAutoBackup.
  ///
  /// In en, this message translates to:
  /// **'Auto-backup'**
  String get settingsAutoBackup;

  /// No description provided for @settingsBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup could not finish. Your data is still safe on your phone.'**
  String get settingsBackupFailed;

  /// No description provided for @settingsAiOfflineBadge.
  ///
  /// In en, this message translates to:
  /// **'100% On-device · Offline'**
  String get settingsAiOfflineBadge;

  /// No description provided for @settingsPrivacyTracking.
  ///
  /// In en, this message translates to:
  /// **'No tracking or ads'**
  String get settingsPrivacyTracking;

  /// No description provided for @settingsPrivacyOfflineAi.
  ///
  /// In en, this message translates to:
  /// **'AI runs offline on your phone'**
  String get settingsPrivacyOfflineAi;

  /// No description provided for @settingsPrivacyDataSafety.
  ///
  /// In en, this message translates to:
  /// **'Your store data stays on your device.'**
  String get settingsPrivacyDataSafety;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0'**
  String get settingsVersion;

  /// No description provided for @settingsLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguageLabel;

  /// No description provided for @settingsSwitchStore.
  ///
  /// In en, this message translates to:
  /// **'Switch or add store'**
  String get settingsSwitchStore;

  /// No description provided for @settingsAddStore.
  ///
  /// In en, this message translates to:
  /// **'+ New store'**
  String get settingsAddStore;

  /// No description provided for @settingsAddStoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add the store. Try again.'**
  String get settingsAddStoreFailed;

  /// No description provided for @settingsLocalBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not complete the backup file action. Try again.'**
  String get settingsLocalBackupFailed;

  /// No description provided for @ulatExpenseDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the expense. Try again.'**
  String get ulatExpenseDeleteFailed;

  /// No description provided for @pinLockedOut.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong tries. Wait {seconds} seconds.'**
  String pinLockedOut(int seconds);

  /// No description provided for @settingsDeleteStore.
  ///
  /// In en, this message translates to:
  /// **'Delete store'**
  String get settingsDeleteStore;

  /// No description provided for @settingsDeleteStoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? All its products, sales, and utang will be removed.'**
  String settingsDeleteStoreConfirm(String name);

  /// No description provided for @settingsSwitchStoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Switch to {name}? Your current store stays saved.'**
  String settingsSwitchStoreConfirm(String name);

  /// No description provided for @settingsActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get settingsActiveBadge;

  /// No description provided for @settingsLanguagePh.
  ///
  /// In en, this message translates to:
  /// **'Filipino'**
  String get settingsLanguagePh;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @unitPiece.
  ///
  /// In en, this message translates to:
  /// **'piece'**
  String get unitPiece;

  /// No description provided for @unitPack.
  ///
  /// In en, this message translates to:
  /// **'pack'**
  String get unitPack;

  /// No description provided for @unitSachet.
  ///
  /// In en, this message translates to:
  /// **'sachet'**
  String get unitSachet;

  /// No description provided for @unitCan.
  ///
  /// In en, this message translates to:
  /// **'can'**
  String get unitCan;

  /// No description provided for @unitBottle.
  ///
  /// In en, this message translates to:
  /// **'bottle'**
  String get unitBottle;

  /// No description provided for @unitBar.
  ///
  /// In en, this message translates to:
  /// **'bar'**
  String get unitBar;

  /// No description provided for @unitBag.
  ///
  /// In en, this message translates to:
  /// **'bag'**
  String get unitBag;

  /// No description provided for @unitKilo.
  ///
  /// In en, this message translates to:
  /// **'kilo'**
  String get unitKilo;

  /// No description provided for @unitLiter.
  ///
  /// In en, this message translates to:
  /// **'liter'**
  String get unitLiter;

  /// No description provided for @failureSaleNoLines.
  ///
  /// In en, this message translates to:
  /// **'Add at least one product to the cart.'**
  String get failureSaleNoLines;

  /// No description provided for @failureSaleQuantityInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid quantity.'**
  String get failureSaleQuantityInvalid;

  /// No description provided for @failureSaleProductNotFound.
  ///
  /// In en, this message translates to:
  /// **'That product is no longer available.'**
  String get failureSaleProductNotFound;

  /// No description provided for @failureSaleCustomerRequired.
  ///
  /// In en, this message translates to:
  /// **'Please choose a suki for utang.'**
  String get failureSaleCustomerRequired;

  /// No description provided for @failureSaleCustomerNotFound.
  ///
  /// In en, this message translates to:
  /// **'That suki could not be found.'**
  String get failureSaleCustomerNotFound;

  /// No description provided for @failureSalePaymentTooLow.
  ///
  /// In en, this message translates to:
  /// **'Cash received is less than the total.'**
  String get failureSalePaymentTooLow;

  /// No description provided for @failureSaleNotFound.
  ///
  /// In en, this message translates to:
  /// **'This sale was already voided or no longer exists.'**
  String get failureSaleNotFound;

  /// No description provided for @failureSaleVoidAfterPayment.
  ///
  /// In en, this message translates to:
  /// **'Cannot void: the customer already paid part of this utang.'**
  String get failureSaleVoidAfterPayment;

  /// No description provided for @failureSaleInsufficientStock.
  ///
  /// In en, this message translates to:
  /// **'Not enough stock for an item in the cart.'**
  String get failureSaleInsufficientStock;

  /// No description provided for @failureSaleStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not save the sale. Your data is safe—try again.'**
  String get failureSaleStoreUnavailable;

  /// No description provided for @failureProductNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a product name.'**
  String get failureProductNameRequired;

  /// No description provided for @failureProductAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price and cost.'**
  String get failureProductAmountInvalid;

  /// No description provided for @failureProductQuantityInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid stock quantity.'**
  String get failureProductQuantityInvalid;

  /// No description provided for @failureProductBarcodeTaken.
  ///
  /// In en, this message translates to:
  /// **'Another product already uses that barcode.'**
  String get failureProductBarcodeTaken;

  /// No description provided for @failureProductNotFound.
  ///
  /// In en, this message translates to:
  /// **'Product not found.'**
  String get failureProductNotFound;

  /// No description provided for @failureProductStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not save product. Try again.'**
  String get failureProductStoreUnavailable;

  /// No description provided for @failureCustomerNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the suki\'s name.'**
  String get failureCustomerNameRequired;

  /// No description provided for @failureCustomerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Suki not found.'**
  String get failureCustomerNotFound;

  /// No description provided for @failureCustomerAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount.'**
  String get failureCustomerAmountInvalid;

  /// No description provided for @failureCustomerPaymentExceedsBalance.
  ///
  /// In en, this message translates to:
  /// **'Payment is more than the remaining balance.'**
  String get failureCustomerPaymentExceedsBalance;

  /// No description provided for @failureCustomerStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not save suki data. Try again.'**
  String get failureCustomerStoreUnavailable;

  /// No description provided for @failureStoreNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your store\'s name.'**
  String get failureStoreNameRequired;

  /// No description provided for @failureStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not save store profile. Try again.'**
  String get failureStoreUnavailable;

  /// No description provided for @settingsLocalBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Local File Backup (.sqlite)'**
  String get settingsLocalBackupTitle;

  /// No description provided for @settingsLocalBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save a copy to your phone or restore from a .sqlite file.'**
  String get settingsLocalBackupSubtitle;

  /// No description provided for @settingsLocalExportButton.
  ///
  /// In en, this message translates to:
  /// **'Export .sqlite'**
  String get settingsLocalExportButton;

  /// No description provided for @settingsLocalImportButton.
  ///
  /// In en, this message translates to:
  /// **'Import .sqlite'**
  String get settingsLocalImportButton;

  /// No description provided for @settingsLocalExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup file saved.'**
  String get settingsLocalExportSuccess;

  /// No description provided for @settingsLocalImportConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Import .sqlite backup?'**
  String get settingsLocalImportConfirmTitle;

  /// No description provided for @settingsLocalImportConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will replace the current store data with the selected backup file.'**
  String get settingsLocalImportConfirmBody;

  /// No description provided for @settingsLocalImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup restored from file.'**
  String get settingsLocalImportSuccess;

  /// No description provided for @settingsLocalImportInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid or corrupted Tinda360 backup file.'**
  String get settingsLocalImportInvalid;

  /// No description provided for @inventoryImportCsvTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import CSV'**
  String get inventoryImportCsvTooltip;

  /// No description provided for @inventoryImportCsvTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Products (CSV)'**
  String get inventoryImportCsvTitle;

  /// No description provided for @inventoryImportCsvSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Columns: name, price, cost, stock, unit, barcode, low_stock'**
  String get inventoryImportCsvSubtitle;

  /// No description provided for @inventoryImportCsvPickButton.
  ///
  /// In en, this message translates to:
  /// **'Choose CSV File'**
  String get inventoryImportCsvPickButton;

  /// No description provided for @inventoryImportCsvTemplateButton.
  ///
  /// In en, this message translates to:
  /// **'Save Sample CSV'**
  String get inventoryImportCsvTemplateButton;

  /// No description provided for @inventoryImportCsvTemplateSaved.
  ///
  /// In en, this message translates to:
  /// **'Sample CSV saved.'**
  String get inventoryImportCsvTemplateSaved;

  /// No description provided for @inventoryImportCsvSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported {imported} products ({skipped} skipped).'**
  String inventoryImportCsvSuccess(int imported, int skipped);

  /// No description provided for @inventoryImportCsvEmpty.
  ///
  /// In en, this message translates to:
  /// **'No valid products found in the CSV file.'**
  String get inventoryImportCsvEmpty;

  /// No description provided for @inventoryImportCsvReadError.
  ///
  /// In en, this message translates to:
  /// **'Could not read the selected CSV file.'**
  String get inventoryImportCsvReadError;

  /// No description provided for @ulatRecentSales.
  ///
  /// In en, this message translates to:
  /// **'Recent Sales'**
  String get ulatRecentSales;

  /// No description provided for @ulatNoRecentSales.
  ///
  /// In en, this message translates to:
  /// **'No sales in this period yet.'**
  String get ulatNoRecentSales;

  /// No description provided for @ulatSaleItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String ulatSaleItemsCount(int count);

  /// No description provided for @ulatSaleDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Sale Receipt'**
  String get ulatSaleDetailTitle;

  /// No description provided for @ulatSaleTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get ulatSaleTotalLabel;

  /// No description provided for @ulatSalePaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get ulatSalePaidLabel;

  /// No description provided for @scannerScannedCount.
  ///
  /// In en, this message translates to:
  /// **'Scanned: {count}'**
  String scannerScannedCount(int count);

  /// No description provided for @ulatShareButton.
  ///
  /// In en, this message translates to:
  /// **'Share report (text)'**
  String get ulatShareButton;

  /// No description provided for @ulatShareRevenueLabel.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get ulatShareRevenueLabel;

  /// No description provided for @ulatShareProfitLabel.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get ulatShareProfitLabel;

  /// No description provided for @ulatShareTransactionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get ulatShareTransactionsLabel;

  /// No description provided for @ulatShareExpensesLabel.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get ulatShareExpensesLabel;

  /// No description provided for @ulatShareNetIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Net income'**
  String get ulatShareNetIncomeLabel;

  /// No description provided for @ulatShareUtangLabel.
  ///
  /// In en, this message translates to:
  /// **'Unpaid utang'**
  String get ulatShareUtangLabel;

  /// No description provided for @ulatShareTopProductsLabel.
  ///
  /// In en, this message translates to:
  /// **'Top 3 products'**
  String get ulatShareTopProductsLabel;

  /// No description provided for @ulatShareCashCountLine.
  ///
  /// In en, this message translates to:
  /// **'Cash count: Expected {expected} · Counted {counted} · {difference}'**
  String ulatShareCashCountLine(
    String expected,
    String counted,
    String difference,
  );

  /// No description provided for @reportsCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get reportsCustom;

  /// No description provided for @reportsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get reportsThisMonth;

  /// No description provided for @reportsLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get reportsLastMonth;

  /// No description provided for @reportsPickDates.
  ///
  /// In en, this message translates to:
  /// **'Pick dates'**
  String get reportsPickDates;

  /// No description provided for @reportsRangeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Pick up to 366 days, ending today or earlier.'**
  String get reportsRangeInvalid;

  /// No description provided for @reportsRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String reportsRangeLabel(String start, String end);

  /// No description provided for @cashCountTitle.
  ///
  /// In en, this message translates to:
  /// **'Close day · Cash count'**
  String get cashCountTitle;

  /// No description provided for @cashCountExpectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Expected cash in drawer'**
  String get cashCountExpectedLabel;

  /// No description provided for @cashCountCountedLabel.
  ///
  /// In en, this message translates to:
  /// **'Counted cash'**
  String get cashCountCountedLabel;

  /// No description provided for @cashCountNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get cashCountNoteLabel;

  /// No description provided for @cashCountSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save cash count'**
  String get cashCountSaveButton;

  /// No description provided for @cashCountSaved.
  ///
  /// In en, this message translates to:
  /// **'Cash count saved.'**
  String get cashCountSaved;

  /// No description provided for @cashCountInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter the cash you counted.'**
  String get cashCountInvalidAmount;

  /// No description provided for @cashCountSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the cash count. Please try again.'**
  String get cashCountSaveFailed;

  /// No description provided for @cashCountOver.
  ///
  /// In en, this message translates to:
  /// **'Over {amount}'**
  String cashCountOver(String amount);

  /// No description provided for @cashCountShort.
  ///
  /// In en, this message translates to:
  /// **'Short {amount}'**
  String cashCountShort(String amount);

  /// No description provided for @cashCountExact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get cashCountExact;

  /// No description provided for @cashCountTodayHeading.
  ///
  /// In en, this message translates to:
  /// **'Counts today'**
  String get cashCountTodayHeading;

  /// No description provided for @cashCountHistoryHeading.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get cashCountHistoryHeading;

  /// No description provided for @cashCountRowSummary.
  ///
  /// In en, this message translates to:
  /// **'Counted {counted} · Expected {expected}'**
  String cashCountRowSummary(String counted, String expected);

  /// No description provided for @cashCountNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No cash counts yet.'**
  String get cashCountNoHistory;

  /// No description provided for @ulatSaleReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get ulatSaleReferenceLabel;

  /// No description provided for @ulatVoidSaleButton.
  ///
  /// In en, this message translates to:
  /// **'Void / Delete Sale'**
  String get ulatVoidSaleButton;

  /// No description provided for @receiptBantayLabel.
  ///
  /// In en, this message translates to:
  /// **'On duty'**
  String get receiptBantayLabel;

  /// No description provided for @bantayChipEmpty.
  ///
  /// In en, this message translates to:
  /// **'Set on duty'**
  String get bantayChipEmpty;

  /// No description provided for @bantayChipLabel.
  ///
  /// In en, this message translates to:
  /// **'On duty: {name}'**
  String bantayChipLabel(String name);

  /// No description provided for @bantayDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Who is minding the store?'**
  String get bantayDialogTitle;

  /// No description provided for @bantayFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get bantayFieldHint;

  /// No description provided for @settingsAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get settingsAddressLabel;

  /// No description provided for @settingsPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get settingsPhoneLabel;

  /// No description provided for @ledgerDeletedByNoReason.
  ///
  /// In en, this message translates to:
  /// **'Deleted by {name}'**
  String ledgerDeletedByNoReason(String name);

  /// No description provided for @ledgerDeletedByWithReason.
  ///
  /// In en, this message translates to:
  /// **'Deleted by {name}: {reason}'**
  String ledgerDeletedByWithReason(String name, String reason);

  /// No description provided for @ulatReturnTitle.
  ///
  /// In en, this message translates to:
  /// **'Return items'**
  String get ulatReturnTitle;

  /// No description provided for @ulatReturnAvailable.
  ///
  /// In en, this message translates to:
  /// **'Can return: {quantity}'**
  String ulatReturnAvailable(String quantity);

  /// No description provided for @ulatReturnQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity to return'**
  String get ulatReturnQuantityLabel;

  /// No description provided for @ulatReturnReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get ulatReturnReasonLabel;

  /// No description provided for @ulatReturnRefundTotal.
  ///
  /// In en, this message translates to:
  /// **'Refund total'**
  String get ulatReturnRefundTotal;

  /// No description provided for @ulatReturnConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Save return'**
  String get ulatReturnConfirmButton;

  /// No description provided for @ulatReturnNothingReturnable.
  ///
  /// In en, this message translates to:
  /// **'Everything in this sale was already returned.'**
  String get ulatReturnNothingReturnable;

  /// No description provided for @ulatReturnSuccessCash.
  ///
  /// In en, this message translates to:
  /// **'Refund {amount}'**
  String ulatReturnSuccessCash(String amount);

  /// No description provided for @ulatReturnSuccessUtang.
  ///
  /// In en, this message translates to:
  /// **'{amount} taken off the customer\'s utang'**
  String ulatReturnSuccessUtang(String amount);

  /// No description provided for @ulatReturnSuccessUtangPartial.
  ///
  /// In en, this message translates to:
  /// **'{credit} taken off utang. Give {cash} back to the customer in cash.'**
  String ulatReturnSuccessUtangPartial(String credit, String cash);

  /// No description provided for @failureSaleVoidAfterReturn.
  ///
  /// In en, this message translates to:
  /// **'This sale has returned items, so it cannot be voided.'**
  String get failureSaleVoidAfterReturn;

  /// No description provided for @failureSaleReturnNothingSelected.
  ///
  /// In en, this message translates to:
  /// **'Enter a quantity to return.'**
  String get failureSaleReturnNothingSelected;

  /// No description provided for @failureSaleReturnQuantityInvalid.
  ///
  /// In en, this message translates to:
  /// **'That return quantity is not valid.'**
  String get failureSaleReturnQuantityInvalid;

  /// No description provided for @failureSaleReturnTooMany.
  ///
  /// In en, this message translates to:
  /// **'Cannot return more than was sold.'**
  String get failureSaleReturnTooMany;

  /// No description provided for @failureSaleReturnSaleVoided.
  ///
  /// In en, this message translates to:
  /// **'This sale was voided, so nothing can be returned.'**
  String get failureSaleReturnSaleVoided;

  /// No description provided for @failureSaleReturnNotFound.
  ///
  /// In en, this message translates to:
  /// **'Sale not found.'**
  String get failureSaleReturnNotFound;

  /// No description provided for @failureSaleReturnStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not save the return. Please try again.'**
  String get failureSaleReturnStoreUnavailable;

  /// No description provided for @ulatVoidSaleConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Void this sale?'**
  String get ulatVoidSaleConfirmTitle;

  /// No description provided for @ulatVoidSaleConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove the sale, restore product stock, and reverse any utang balance.'**
  String get ulatVoidSaleConfirmBody;

  /// No description provided for @ulatVoidSaleSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sale voided and stock restored.'**
  String get ulatVoidSaleSuccess;

  /// No description provided for @inventoryExportCsvButton.
  ///
  /// In en, this message translates to:
  /// **'Export Products CSV'**
  String get inventoryExportCsvButton;

  /// No description provided for @inventoryExportCsvSuccess.
  ///
  /// In en, this message translates to:
  /// **'Products CSV saved.'**
  String get inventoryExportCsvSuccess;

  /// No description provided for @reportsExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export Sales CSV'**
  String get reportsExportCsv;

  /// No description provided for @reportsExportCsvSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sales CSV saved.'**
  String get reportsExportCsvSuccess;

  /// No description provided for @ulatExpensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get ulatExpensesTitle;

  /// No description provided for @ulatAddExpenseButton.
  ///
  /// In en, this message translates to:
  /// **'+ Add Expense'**
  String get ulatAddExpenseButton;

  /// No description provided for @ulatNoExpenses.
  ///
  /// In en, this message translates to:
  /// **'No expenses in this period.'**
  String get ulatNoExpenses;

  /// No description provided for @ulatNetIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Net income (after expenses)'**
  String get ulatNetIncomeLabel;

  /// No description provided for @ulatExpenseTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Expense description'**
  String get ulatExpenseTitleLabel;

  /// No description provided for @ulatExpenseAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get ulatExpenseAmountLabel;

  /// No description provided for @ulatExpenseSaved.
  ///
  /// In en, this message translates to:
  /// **'Expense recorded.'**
  String get ulatExpenseSaved;

  /// No description provided for @settingsPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Store PIN Lock'**
  String get settingsPinTitle;

  /// No description provided for @settingsPinSubtitleOn.
  ///
  /// In en, this message translates to:
  /// **'PIN required before voiding sales'**
  String get settingsPinSubtitleOn;

  /// No description provided for @settingsPinSubtitleOff.
  ///
  /// In en, this message translates to:
  /// **'Protect sensitive actions with a 4-digit PIN'**
  String get settingsPinSubtitleOff;

  /// No description provided for @settingsPinSetButton.
  ///
  /// In en, this message translates to:
  /// **'Set 4-Digit PIN'**
  String get settingsPinSetButton;

  /// No description provided for @settingsPinRemoveButton.
  ///
  /// In en, this message translates to:
  /// **'Remove PIN'**
  String get settingsPinRemoveButton;

  /// No description provided for @settingsPinPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter 4-Digit Store PIN'**
  String get settingsPinPromptTitle;

  /// No description provided for @settingsPinSetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Store PIN saved.'**
  String get settingsPinSetSuccess;

  /// No description provided for @settingsPinRemoved.
  ///
  /// In en, this message translates to:
  /// **'Store PIN removed.'**
  String get settingsPinRemoved;

  /// No description provided for @receiptPrint58mm.
  ///
  /// In en, this message translates to:
  /// **'Print 58mm Receipt'**
  String get receiptPrint58mm;

  /// No description provided for @receiptPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt Preview'**
  String get receiptPreviewTitle;

  /// No description provided for @receiptPreviewPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get receiptPreviewPrint;

  /// No description provided for @csvPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'CSV Preview'**
  String get csvPreviewTitle;

  /// No description provided for @csvPreviewExport.
  ///
  /// In en, this message translates to:
  /// **'Export File'**
  String get csvPreviewExport;

  /// No description provided for @csvPreviewRowCount.
  ///
  /// In en, this message translates to:
  /// **'{count} rows'**
  String csvPreviewRowCount(int count);

  /// No description provided for @csvPreviewMoreRows.
  ///
  /// In en, this message translates to:
  /// **'... and {count} more'**
  String csvPreviewMoreRows(int count);

  /// No description provided for @chatWelcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'{greeting} I\'m Yumi, your Smart Store Assistant. Ask me anything about your store\'s sales, stock, or utang!'**
  String chatWelcomeMessage(String greeting);

  /// No description provided for @pinRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Your Recovery Code'**
  String get pinRecoveryTitle;

  /// No description provided for @pinRecoveryBody.
  ///
  /// In en, this message translates to:
  /// **'Write down or copy this one-time code. You can use it to reset your PIN if you forget it offline.'**
  String get pinRecoveryBody;

  /// No description provided for @pinRecoveryCopied.
  ///
  /// In en, this message translates to:
  /// **'Recovery code copied.'**
  String get pinRecoveryCopied;

  /// No description provided for @pinCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get pinCopy;

  /// No description provided for @pinDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get pinDone;

  /// No description provided for @pinEnterFourDigits.
  ///
  /// In en, this message translates to:
  /// **'Enter a 4-digit PIN.'**
  String get pinEnterFourDigits;

  /// No description provided for @pinIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN. Try again.'**
  String get pinIncorrect;

  /// No description provided for @pinInvalidRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid recovery code.'**
  String get pinInvalidRecoveryCode;

  /// No description provided for @pinBiometricFailed.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock failed or cancelled.'**
  String get pinBiometricFailed;

  /// No description provided for @pinGoogleMismatch.
  ///
  /// In en, this message translates to:
  /// **'Google account did not match.'**
  String get pinGoogleMismatch;

  /// No description provided for @pinResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Store PIN'**
  String get pinResetTitle;

  /// No description provided for @pinUseBiometric.
  ///
  /// In en, this message translates to:
  /// **'Use Fingerprint / Screen Lock'**
  String get pinUseBiometric;

  /// No description provided for @pinForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN?'**
  String get pinForgot;

  /// No description provided for @pinRecoveryCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery code (e.g. T360-XXXX)'**
  String get pinRecoveryCodeLabel;

  /// No description provided for @pinVerifyGoogle.
  ///
  /// In en, this message translates to:
  /// **'Verify with Google Account'**
  String get pinVerifyGoogle;

  /// No description provided for @pinBackToPin.
  ///
  /// In en, this message translates to:
  /// **'Back to PIN'**
  String get pinBackToPin;

  /// No description provided for @pinResetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset PIN'**
  String get pinResetButton;

  /// No description provided for @pinUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get pinUnlock;

  /// No description provided for @pinDamaged.
  ///
  /// In en, this message translates to:
  /// **'PIN data is damaged. Unlock with fingerprint, screen lock or Google, then set a new PIN.'**
  String get pinDamaged;

  /// No description provided for @pinRemoveDamaged.
  ///
  /// In en, this message translates to:
  /// **'Remove damaged PIN'**
  String get pinRemoveDamaged;

  /// No description provided for @pinMustBeFourDigits.
  ///
  /// In en, this message translates to:
  /// **'PIN must be exactly 4 digits.'**
  String get pinMustBeFourDigits;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match.'**
  String get pinMismatch;

  /// No description provided for @pinNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New 4-digit PIN'**
  String get pinNewLabel;

  /// No description provided for @pinConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm 4-digit PIN'**
  String get pinConfirmLabel;

  /// No description provided for @ledgerHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Ledger History'**
  String get ledgerHistoryTitle;

  /// No description provided for @ledgerReminderCopied.
  ///
  /// In en, this message translates to:
  /// **'Reminder copied to clipboard'**
  String get ledgerReminderCopied;

  /// No description provided for @receiptPrintDialogFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open print dialog.'**
  String get receiptPrintDialogFailed;

  /// No description provided for @ulatExpenseInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid expense name and amount.'**
  String get ulatExpenseInvalid;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @settingsSwitchStoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch store. Try again.'**
  String get settingsSwitchStoreFailed;

  /// No description provided for @settingsDeleteStoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete store. Try again.'**
  String get settingsDeleteStoreFailed;

  /// No description provided for @posRemovedFromCart.
  ///
  /// In en, this message translates to:
  /// **'Removed {name}'**
  String posRemovedFromCart(String name);

  /// No description provided for @receiptTotal.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get receiptTotal;

  /// No description provided for @receiptPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get receiptPayment;

  /// No description provided for @receiptPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get receiptPaid;

  /// No description provided for @receiptChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get receiptChange;

  /// No description provided for @receiptUtang.
  ///
  /// In en, this message translates to:
  /// **'Utang'**
  String get receiptUtang;

  /// No description provided for @receiptThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you!'**
  String get receiptThankYou;

  /// No description provided for @receiptNoItems.
  ///
  /// In en, this message translates to:
  /// **'(No items)'**
  String get receiptNoItems;

  /// No description provided for @inventoryImportSkippedRows.
  ///
  /// In en, this message translates to:
  /// **'Check rows: {rows} (missing name or price, bad number, unknown unit, or duplicate barcode).'**
  String inventoryImportSkippedRows(String rows);
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
      <String>['en', 'fil'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fil':
      return AppLocalizationsFil();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
