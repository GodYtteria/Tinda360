import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fil.dart';

// ignore_for_file: type=lint

abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fil'),
  ];

  String get appTitle;

  String get homeDatabaseReady;

  String homeProductCount(int count);

  String homeLowStockCount(int count);

  String get homeLoadFailed;

  String get commonRetry;

  String get commonClose;

  String get commonBack;

  String get commonSave;

  String get commonSwitch;

  String get commonCancel;

  String get commonNext;

  String get commonDelete;

  String get commonAll;

  String get commonSearch;

  String get splashPreparingAi;

  String get splashTagline;

  String get onboardingStep1Title;

  String get onboardingStep1Subtitle;

  String get onboardingStoreNameLabel;

  String get onboardingStoreNameHint;

  String get onboardingStep2Title;

  String get onboardingStep2Subtitle;

  String get onboardingNewStoreTitle;

  String get onboardingNewStoreSubtitle;

  String get onboardingSampleItemsToggle;

  String get onboardingRestoreTitle;

  String get onboardingRestoreSubtitle;

  String get onboardingGoogleButton;

  String get onboardingRestoreUnavailable;

  String get navSales;

  String get navInventory;

  String get navUtang;

  String get navReports;

  String get posSearchHint;

  String get posScanBarcode;

  String get posOpenSettings;

  String get posGreeting;

  String get posGreetingDismiss;

  String posAddToCart(String name);

  String posRemoveFromCart(String name);

  String posStockLabel(String qty);

  String posOutOfStock(String name);

  String get posLowStockBadge;

  String get posOutOfStockBadge;

  String get checkoutExactAmountChip;

  String get posBackupStaleTitle;

  String get posBackupNeverTitle;

  String get posBackupWarningBody;

  String get posQuantityMode;

  String get posAmountMode;

  String posAmountEquals(String quantity);

  String posCartItems(int count);

  String get posPayButton;

  String get posEmptyTitle;

  String get posEmptyBody;

  String get posStorageFullTitle;

  String get posStorageFullBody;

  String get checkoutTitle;

  String get checkoutTotalLabel;

  String get checkoutMethodCash;

  String get checkoutMethodEwallet;

  String get checkoutMethodUtang;

  String get checkoutTenderedLabel;

  String get checkoutChangeLabel;

  String get checkoutPaidNowLabel;

  String checkoutPaidNowRemaining(String amount);

  String get checkoutPaidNowInvalid;

  String checkoutPriceDialogTitle(String product);

  String checkoutPriceNormal(String price);

  String get checkoutPriceLabel;

  String get checkoutPriceInvalid;

  String get checkoutPriceReset;

  String get failureSalePaidNowInvalid;

  String get failureSalePriceInvalid;

  String get receiptNumberLabel;

  String get receiptSukiLabel;

  String get receiptReferenceLabel;

  String get checkoutEwalletRefLabel;

  String get checkoutEwalletRefHint;

  String get checkoutEwalletReminder;

  String get checkoutSelectSuki;

  String get checkoutNoSuki;

  String get checkoutUtangNote;

  String get checkoutFinishSale;

  String get checkoutRecordUtang;

  String get saleDoneTitle;

  String get saleDoneTotal;

  String get saleDonePaid;

  String get saleDoneChange;

  String get saleDoneNewSale;

  String get saleDoneShareReceipt;

  String get saleDoneShareFailed;

  String get saleDoneReceiptCopied;

  String get inventoryLowFilter;

  String get inventoryAddProduct;

  String get inventoryEmptyTitle;

  String get inventoryEmptyBody;

  String get inventoryFilterEmptyTitle;

  String get inventoryFilterEmptyBody;

  String inventorySummary(int total, int low);

  String get productSheetAddTitle;

  String get productSheetEditTitle;

  String get productNameLabel;

  String get productNameHint;

  String get productPriceLabel;

  String get productCostLabel;

  String get productNoCountSwitch;

  String get productNoCountHint;

  String get productExpiryLabel;

  String get productExpiryClear;

  String get productDuplicateNameWarning;

  String get productPriceZeroWarning;

  String get inventoryNoCountLabel;

  String inventoryExpiryDaysBadge(int count);

  String get inventoryExpiredBadge;

  String get inventoryExpiringFilter;

  String get inventoryShareShoppingList;

  String get shoppingListHeader;

  String shoppingListLine(String name, String amount, String unit);

  String get productRestockCostLabel;

  String get productStockHistoryButton;

  String get stockHistoryTitle;

  String get stockHistoryEmpty;

  String stockHistoryAfter(String stock);

  String get stockReasonInitial;

  String get stockReasonRestock;

  String get stockReasonAdjust;

  String get stockReasonReturn;

  String get receiptRefunded;

  String get receiptNetTotal;

  String get checkoutCreditNearTitle;

  String checkoutCreditNearBody(String name, String balance, String limit);

  String get reportsExportCsvError;

  String get ledgerDeleteConfirmTitle;

  String ledgerDeleteConfirmBody(String kind, String amount, String date);

  String get ledgerDeleteReasonLabel;

  String get ledgerDeleteConfirmAction;

  String get ledgerDeleteDone;

  String ledgerDeletedWithReason(String reason);

  String get ledgerDeletedNoReason;

  String get ledgerNotDeletableHint;

  String get failureLedgerEntryNotFound;

  String get failureLedgerEntryAlreadyDeleted;

  String get failureLedgerEntryNotDeletable;

  String get failureLedgerDeleteWouldGoNegative;

  String get checkoutInterestLabel;

  String get checkoutInterestPrompt;

  String get checkoutInterestPercentInvalid;

  String get checkoutInterestAmountInvalid;

  String get checkoutInterestTooMuch;

  String checkoutInterestPreview(String utang, String interest, String total);

  String get receiptInterest;

  String get failureSaleInterestInvalid;

  String get productUtangPriceLabel;

  String get checkoutUtangPriceTag;

  String get failureCustomerInterestAmountChanged;

  String checkoutShortfallPrompt(String amount);

  String get yumiChipLowStock;

  String get yumiChipSalesToday;

  String get yumiChipProductCount;

  String get yumiChipSlowMoving;

  String get yumiChipWhoHasUtang;

  String get yumiChipUtangRisk;

  String get yumiChipExpensesWeek;

  String get yumiChipCompareYesterday;

  String get yumiChipWhatCanYouDo;

  String get yumiHintPos;

  String get yumiHintInventory;

  String get yumiHintUtang;

  String get yumiHintReports;

  String get yumiHintSettings;

  String get sukiTuboLabel;

  String get sukiTuboHint;

  String get sukiTuboInvalid;

  String get ledgerKindTubo;

  String get ledgerAddTubo;

  String get ledgerTuboConfirmTitle;

  String ledgerTuboConfirmBody(String balance, String percent, String amount);

  String get ledgerTuboConfirmAction;

  String ledgerTuboAdded(String amount);

  String ledgerReminderTuboMessage(
    String customerName,
    String storeName,
    String utang,
    String tubo,
    String total,
  );

  String get failureCustomerInterestRateNotSet;

  String get failureCustomerInterestNoBalance;

  String get stockReasonSale;

  String get reportPdfMetricHeader;

  String get reportPdfValueHeader;

  String get reportPdfProductHeader;

  String get reportPdfQuantitySoldHeader;

  String get reportPdfRevenueHeader;

  String reportPdfPreparedBy(String storeName);

  String get sukiEditAction;

  String get sukiDeleteAction;

  String get sukiEditTitle;

  String get sukiSaveChanges;

  String get sukiDeleteConfirmTitle;

  String sukiDeleteConfirmBody(String name);

  String get failureCustomerHasBalance;

  String get ledgerShareReminder;

  String get ledgerCopyReminder;

  String get ledgerEmptyEntries;

  String get ledgerKindUtang;

  String get ledgerKindPayment;

  String get ledgerReminderDefaultStore;

  String ledgerReminderMessage(
    String customerName,
    String storeName,
    String balance,
  );

  String inventoryCostSummary(String amount);

  String productProfitPerSale(String amount);

  String get productUnitLabel;

  String get productCategoryLabel;

  String get productInitialStockLabel;

  String get productAdjustStockLabel;

  String productCurrentStockLabel(String qty);

  String get productLowStockLabel;

  String get productBarcodeLabel;

  String get productDeleteButton;

  String get productDeleteConfirm;

  String get utangTitle;

  String get utangTotalLabel;

  String utangSukiCount(int count);

  String get utangSearchHint;

  String get utangPayButton;

  String get utangAddSuki;

  String get utangBalanceLabel;

  String get utangOverLimit;

  String get utangEmptyTitle;

  String get utangEmptyBody;

  String get utangPayTitle;

  String get utangNewSukiTitle;

  String get utangCurrentBalance;

  String utangAgeDays(int count);

  String get utangExportCsv;

  String checkoutCreditLimitExceeded(String limit);

  String get checkoutCreditLimitOverride;

  String get utangFullPayment;

  String get utangPartialPayment;

  String get utangPaymentAmountLabel;

  String get utangNewBalanceLabel;

  String get utangRecordPayment;

  String get utangSukiNameLabel;

  String get utangSukiPhoneLabel;

  String get utangSukiLimitLabel;

  String get utangSaveSuki;

  String get reportsTitle;

  String get reportsToday;

  String get reportsWeek;

  String get reportsMonth;

  String get reportsSalesCard;

  String get reportsProfitCard;

  String get reportsTransactionsCard;

  String get reportsNewUtangCard;

  String get reportsChartTitle;

  String reportsChartTitlePeriod(String period);

  String get reportsTopProductsTitle;

  String reportsTopProductSold(String qty, String amount);

  String get reportsAskAi;

  String get reportsExportPdf;

  String get reportsExportPdfError;

  String get reportsEmptyTitle;

  String reportsEmptyTitlePeriod(String period);

  String get reportsEmptyBody;

  String get chatTitle;

  String get chatStatusOffline;

  String get chatStatusThinking;

  String get chatThinkingBubble;

  String get chatInputHint;

  String get chatSend;

  String get chatVoice;

  String chatSourcePrefix(String source);

  String get chatOpenTindaAi;

  String get chatSuggestionSales;

  String get chatSuggestionLowStock;

  String get chatSuggestionUtang;

  String get chatModelUnavailable;

  String get chatErrorReply;

  String get chatSourceSales;

  String get chatSourceInventory;

  String get chatSourceUtang;

  String get chatSourceSummary;

  String get chatReplySalesEmpty;

  String chatReplySalesSummary(int count, String revenue, String profit);

  String chatReplyLowStockNone(int count);

  String chatReplyLowStockFound(int count, String names);

  String get chatReplyUtangNone;

  String chatReplyUtangSummary(String total, int count, String topNames);

  String chatReplyOverview(
    String revenue,
    int count,
    int lowCount,
    String totalUtang,
  );

  String get posScanUnavailable;

  String get posScanTorchTooltip;

  String get scannerManualHint;

  String get scannerUseCode;

  String scannerProductNotFound(String code);

  String get productStockDecrement;

  String get settingsTitle;

  String get settingsSectionBackup;

  String get settingsSectionAi;

  String get settingsSectionStore;

  String get settingsSectionPrivacy;

  String get settingsSectionAbout;

  String get settingsSectionStorage;

  String get settingsStorageSizeLabel;

  String get settingsCompactButton;

  String settingsCompactDone(String size);

  String get settingsNoBackupWarningTitle;

  String get settingsNoBackupWarningBody;

  String get settingsBackupNotConnected;

  String get settingsBackupConnecting;

  String get settingsBackupConnected;

  String get settingsBackupChooseTitle;

  String get settingsBackupUsePhone;

  String get settingsBackupRestore;

  String get settingsBackupSyncNow;

  String get settingsBackupDisconnect;

  String settingsBackupLastSync(String time);

  String get settingsBackupJustNow;

  String get settingsBackupWifiOnly;

  String get settingsAutoBackup;

  String get settingsBackupFailed;

  String get settingsAiOfflineBadge;

  String get settingsPrivacyTracking;

  String get settingsPrivacyOfflineAi;

  String get settingsPrivacyDataSafety;

  String get settingsVersion;

  String get settingsLanguageLabel;

  String get settingsSwitchStore;

  String get settingsAddStore;

  String get settingsAddStoreFailed;

  String get settingsLocalBackupFailed;

  String get ulatExpenseDeleteFailed;

  String pinLockedOut(int seconds);

  String get settingsDeleteStore;

  String settingsDeleteStoreConfirm(String name);

  String settingsSwitchStoreConfirm(String name);

  String get settingsActiveBadge;

  String get settingsLanguagePh;

  String get settingsLanguageEn;

  String get unitPiece;

  String get unitPack;

  String get unitSachet;

  String get unitCan;

  String get unitBottle;

  String get unitBar;

  String get unitBag;

  String get unitKilo;

  String get unitLiter;

  String get failureSaleNoLines;

  String get failureSaleQuantityInvalid;

  String get failureSaleProductNotFound;

  String get failureSaleCustomerRequired;

  String get failureSaleCustomerNotFound;

  String get failureSalePaymentTooLow;

  String get failureSaleNotFound;

  String get failureSaleVoidAfterPayment;

  String get failureSaleInsufficientStock;

  String get failureSaleStoreUnavailable;

  String get failureProductNameRequired;

  String get failureProductAmountInvalid;

  String get failureProductQuantityInvalid;

  String get failureProductBarcodeTaken;

  String get failureProductNotFound;

  String get failureProductStoreUnavailable;

  String get failureCustomerNameRequired;

  String get failureCustomerNotFound;

  String get failureCustomerAmountInvalid;

  String get failureCustomerPaymentExceedsBalance;

  String get failureCustomerStoreUnavailable;

  String get failureStoreNameRequired;

  String get failureStoreUnavailable;

  String get settingsLocalBackupTitle;

  String get settingsLocalBackupSubtitle;

  String get settingsLocalExportButton;

  String get settingsLocalImportButton;

  String get settingsLocalExportSuccess;

  String get settingsLocalImportConfirmTitle;

  String get settingsLocalImportConfirmBody;

  String get settingsLocalImportSuccess;

  String get settingsLocalImportInvalid;

  String get inventoryImportCsvTooltip;

  String get inventoryImportCsvTitle;

  String get inventoryImportCsvSubtitle;

  String get inventoryImportCsvPickButton;

  String get inventoryImportCsvTemplateButton;

  String get inventoryImportCsvTemplateSaved;

  String inventoryImportCsvSuccess(int imported, int skipped);

  String get inventoryImportCsvEmpty;

  String get inventoryImportCsvReadError;

  String get ulatRecentSales;

  String get ulatNoRecentSales;

  String ulatSaleItemsCount(int count);

  String get ulatSaleDetailTitle;

  String get ulatSaleTotalLabel;

  String get ulatSalePaidLabel;

  String scannerScannedCount(int count);

  String get ulatShareButton;

  String get ulatShareRevenueLabel;

  String get ulatShareProfitLabel;

  String get ulatShareTransactionsLabel;

  String get ulatShareExpensesLabel;

  String get ulatShareNetIncomeLabel;

  String get ulatShareUtangLabel;

  String get ulatShareTopProductsLabel;

  String ulatShareCashCountLine(
    String expected,
    String counted,
    String difference,
  );

  String get reportsCustom;

  String get reportsThisMonth;

  String get reportsLastMonth;

  String get reportsPickDates;

  String get reportsRangeInvalid;

  String reportsRangeLabel(String start, String end);

  String get cashCountTitle;

  String get cashCountExpectedLabel;

  String get cashCountCountedLabel;

  String get cashCountNoteLabel;

  String get cashCountSaveButton;

  String get cashCountSaved;

  String get cashCountInvalidAmount;

  String get cashCountSaveFailed;

  String cashCountOver(String amount);

  String cashCountShort(String amount);

  String get cashCountExact;

  String get cashCountTodayHeading;

  String get cashCountHistoryHeading;

  String cashCountRowSummary(String counted, String expected);

  String get cashCountNoHistory;

  String get ulatSaleReferenceLabel;

  String get ulatVoidSaleButton;

  String get receiptBantayLabel;

  String get bantayChipEmpty;

  String bantayChipLabel(String name);

  String get bantayDialogTitle;

  String get bantayFieldHint;

  String get settingsAddressLabel;

  String get settingsPhoneLabel;

  String ledgerDeletedByNoReason(String name);

  String ledgerDeletedByWithReason(String name, String reason);

  String get ulatReturnTitle;

  String ulatReturnAvailable(String quantity);

  String get ulatReturnQuantityLabel;

  String get ulatReturnReasonLabel;

  String get ulatReturnRefundTotal;

  String get ulatReturnConfirmButton;

  String get ulatReturnNothingReturnable;

  String ulatReturnSuccessCash(String amount);

  String ulatReturnSuccessUtang(String amount);

  String ulatReturnSuccessUtangPartial(String credit, String cash);

  String get failureSaleVoidAfterReturn;

  String get failureSaleReturnNothingSelected;

  String get failureSaleReturnQuantityInvalid;

  String get failureSaleReturnTooMany;

  String get failureSaleReturnSaleVoided;

  String get failureSaleReturnNotFound;

  String get failureSaleReturnStoreUnavailable;

  String get ulatVoidSaleConfirmTitle;

  String get ulatVoidSaleConfirmBody;

  String get ulatVoidSaleSuccess;

  String get inventoryExportCsvButton;

  String get inventoryExportCsvSuccess;

  String get reportsExportCsv;

  String get reportsExportCsvSuccess;

  String get ulatExpensesTitle;

  String get ulatAddExpenseButton;

  String get ulatNoExpenses;

  String get ulatNetIncomeLabel;

  String get ulatExpenseTitleLabel;

  String get ulatExpenseAmountLabel;

  String get ulatExpenseSaved;

  String get settingsPinTitle;

  String get settingsPinSubtitleOn;

  String get settingsPinSubtitleOff;

  String get settingsPinSetButton;

  String get settingsPinRemoveButton;

  String get settingsPinPromptTitle;

  String get settingsPinSetSuccess;

  String get settingsPinRemoved;

  String get receiptPrint58mm;

  String get receiptPreviewTitle;

  String get receiptPreviewPrint;

  String get csvPreviewTitle;

  String get csvPreviewExport;

  String csvPreviewRowCount(int count);

  String csvPreviewMoreRows(int count);

  String chatWelcomeMessage(String greeting);

  String get pinRecoveryTitle;

  String get pinRecoveryBody;

  String get pinRecoveryCopied;

  String get pinCopy;

  String get pinDone;

  String get pinEnterFourDigits;

  String get pinIncorrect;

  String get pinInvalidRecoveryCode;

  String get pinBiometricFailed;

  String get pinGoogleMismatch;

  String get pinResetTitle;

  String get pinUseBiometric;

  String get pinForgot;

  String get pinRecoveryCodeLabel;

  String get pinVerifyGoogle;

  String get pinBackToPin;

  String get pinResetButton;

  String get pinUnlock;

  String get pinDamaged;

  String get pinRemoveDamaged;

  String get pinMustBeFourDigits;

  String get pinMismatch;

  String get pinNewLabel;

  String get pinConfirmLabel;

  String get ledgerHistoryTitle;

  String get ledgerReminderCopied;

  String get receiptPrintDialogFailed;

  String get ulatExpenseInvalid;

  String get commonUndo;

  String get settingsSwitchStoreFailed;

  String get settingsDeleteStoreFailed;

  String posRemovedFromCart(String name);

  String get receiptTotal;

  String get receiptPayment;

  String get receiptPaid;

  String get receiptChange;

  String get receiptUtang;

  String get receiptThankYou;

  String get receiptNoItems;

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
