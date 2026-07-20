// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tinda 360';

  @override
  String get homeDatabaseReady => 'Store data is ready';

  @override
  String homeProductCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '1 product',
      zero: 'No products yet',
    );
    return '$_temp0';
  }

  @override
  String homeLowStockCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products are low on stock',
      one: '1 product is low on stock',
      zero: 'Nothing is low on stock',
    );
    return '$_temp0';
  }

  @override
  String get homeLoadFailed => 'The store data could not be opened.';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonClose => 'Close';

  @override
  String get commonBack => 'Back';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonNext => 'Next';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonAll => 'All';

  @override
  String get commonSearch => 'Search';

  @override
  String get splashPreparingAi => 'Preparing AI...';

  @override
  String get splashTagline => 'Smart POS with AI, even offline';

  @override
  String get onboardingStep1Title => 'What is your store\'s name?';

  @override
  String get onboardingStep1Subtitle =>
      'This appears on your reports and receipts.';

  @override
  String get onboardingStoreNameLabel => 'Store name';

  @override
  String get onboardingStoreNameHint => 'e.g. Aling Nena\'s Store';

  @override
  String get onboardingStep2Title => 'Do you have a backup?';

  @override
  String get onboardingStep2Subtitle =>
      'You can start fresh or restore from Google Drive.';

  @override
  String get onboardingNewStoreTitle => 'I am a new store';

  @override
  String get onboardingNewStoreSubtitle =>
      'Start right away, offline on your phone.';

  @override
  String get onboardingSampleItemsToggle =>
      'Add sample products to try right away';

  @override
  String get onboardingRestoreTitle => 'Restore from Google';

  @override
  String get onboardingRestoreSubtitle =>
      'Bring back products, sales, and utang.';

  @override
  String get onboardingGoogleButton => 'Continue with Google';

  @override
  String get onboardingRestoreUnavailable =>
      'Google Drive restore is not connected yet. You can start fresh and back up later.';

  @override
  String get navSales => 'POS';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navUtang => 'Utang';

  @override
  String get navReports => 'Reports';

  @override
  String get posSearchHint => 'Search product or barcode...';

  @override
  String get posScanBarcode => 'Scan barcode';

  @override
  String get posOpenSettings => 'Settings';

  @override
  String get posGreeting =>
      'Magandang araw! Ready to sell. Tap any product to add to cart.';

  @override
  String get posGreetingDismiss => 'Dismiss greeting';

  @override
  String posAddToCart(String name) {
    return 'Add $name';
  }

  @override
  String posRemoveFromCart(String name) {
    return 'Remove $name';
  }

  @override
  String posStockLabel(String qty) {
    return 'Stock $qty';
  }

  @override
  String get posLowStockBadge => 'Low';

  @override
  String posCartItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return 'Cart · $_temp0';
  }

  @override
  String get posPayButton => 'Pay';

  @override
  String get posEmptyTitle => 'No products yet';

  @override
  String get posEmptyBody => 'Add products in Inventory to start selling.';

  @override
  String get posStorageFullTitle => 'Phone storage is almost full';

  @override
  String get posStorageFullBody =>
      'Your sales still continue. Free up space soon so data stays safe.';

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get checkoutTotalLabel => 'Total';

  @override
  String get checkoutMethodCash => 'Cash';

  @override
  String get checkoutMethodEwallet => 'E-wallet';

  @override
  String get checkoutMethodUtang => 'Utang';

  @override
  String get checkoutTenderedLabel => 'Cash received';

  @override
  String get checkoutChangeLabel => 'Change';

  @override
  String get checkoutEwalletRefLabel => 'Reference number (optional)';

  @override
  String get checkoutEwalletRefHint => 'Last 4 digits or ref no.';

  @override
  String get checkoutEwalletReminder =>
      'Make sure the payment is received before completing the sale.';

  @override
  String get checkoutSelectSuki => 'Choose suki';

  @override
  String get checkoutNoSuki => 'No suki added yet. Add a suki in Utang first.';

  @override
  String get checkoutUtangNote =>
      'The total will be added to the suki\'s balance.';

  @override
  String get checkoutFinishSale => 'Complete sale';

  @override
  String get checkoutRecordUtang => 'Record as utang';

  @override
  String get saleDoneTitle => 'Sale complete!';

  @override
  String get saleDoneTotal => 'Total';

  @override
  String get saleDonePaid => 'Paid';

  @override
  String get saleDoneChange => 'Change';

  @override
  String get saleDoneNewSale => 'New sale';

  @override
  String get saleDoneShareReceipt => 'Share receipt';

  @override
  String get saleDoneReceiptCopied => 'Receipt summary ready to share.';

  @override
  String get inventoryLowFilter => 'Low stock';

  @override
  String get inventoryAddProduct => '+ Product';

  @override
  String get inventoryEmptyTitle => 'No products yet';

  @override
  String get inventoryEmptyBody => 'Tap + Product to add your first item.';

  @override
  String get inventoryFilterEmptyTitle => 'No matching products';

  @override
  String get inventoryFilterEmptyBody => 'Try a different search or filter.';

  @override
  String inventorySummary(int total, int low) {
    return '$total products · $low low';
  }

  @override
  String get productSheetAddTitle => 'Add product';

  @override
  String get productSheetEditTitle => 'Edit product';

  @override
  String get productNameLabel => 'Product name';

  @override
  String get productNameHint => 'e.g. Lucky Me Pancit Canton';

  @override
  String get productPriceLabel => 'Selling price (₱)';

  @override
  String get productCostLabel => 'Cost / puhunan (₱)';

  @override
  String productProfitPerSale(String amount) {
    return 'Profit per sale: $amount';
  }

  @override
  String get productUnitLabel => 'Unit';

  @override
  String get productCategoryLabel => 'Category (optional)';

  @override
  String get productInitialStockLabel => 'Starting stock';

  @override
  String get productAdjustStockLabel => 'Adjust stock';

  @override
  String productCurrentStockLabel(String qty) {
    return 'Current stock: $qty';
  }

  @override
  String get productLowStockLabel => 'Low-stock alert at';

  @override
  String get productBarcodeLabel => 'Barcode (optional)';

  @override
  String get productDeleteButton => 'Delete product';

  @override
  String get productDeleteConfirm => 'Remove this product from active items?';

  @override
  String get utangTitle => 'Utang';

  @override
  String get utangTotalLabel => 'Total utang';

  @override
  String utangSukiCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suki',
      one: '1 suki',
      zero: 'No suki',
    );
    return '$_temp0';
  }

  @override
  String get utangSearchHint => 'Search suki...';

  @override
  String get utangPayButton => 'Pay';

  @override
  String get utangAddSuki => '+ Suki';

  @override
  String get utangBalanceLabel => 'Balance';

  @override
  String get utangOverLimit => 'Over limit';

  @override
  String get utangEmptyTitle => 'No utang right now';

  @override
  String get utangEmptyBody => 'Suki balances will show up here.';

  @override
  String get utangPayTitle => 'Pay utang';

  @override
  String get utangNewSukiTitle => 'New suki';

  @override
  String get utangCurrentBalance => 'Current balance';

  @override
  String get utangFullPayment => 'Full payment';

  @override
  String get utangPartialPayment => 'Partial';

  @override
  String get utangPaymentAmountLabel => 'Payment amount (₱)';

  @override
  String get utangNewBalanceLabel => 'New balance';

  @override
  String get utangRecordPayment => 'Save payment';

  @override
  String get utangSukiNameLabel => 'Suki name';

  @override
  String get utangSukiPhoneLabel => 'Mobile number (optional)';

  @override
  String get utangSukiLimitLabel => 'Utang limit (optional)';

  @override
  String get utangSaveSuki => 'Save suki';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsToday => 'Today';

  @override
  String get reportsWeek => 'Week';

  @override
  String get reportsMonth => 'Month';

  @override
  String get reportsSalesCard => 'Sales';

  @override
  String get reportsProfitCard => 'Profit';

  @override
  String get reportsTransactionsCard => 'Transactions';

  @override
  String get reportsNewUtangCard => 'New utang';

  @override
  String get reportsChartTitle => 'Sales trend';

  @override
  String reportsChartTitlePeriod(String period) {
    return 'Sales trend · $period';
  }

  @override
  String get reportsTopProductsTitle => 'Top 3 products';

  @override
  String reportsTopProductSold(String qty, String amount) {
    return '$qty sold · $amount';
  }

  @override
  String get reportsAskAi => 'Ask Smart Store Assistant about this report';

  @override
  String get reportsExportPdf => 'Export PDF report';

  @override
  String get reportsExportPdfError => 'Could not generate PDF report.';

  @override
  String get reportsEmptyTitle => 'No sales in this period';

  @override
  String reportsEmptyTitlePeriod(String period) {
    return 'No sales ($period)';
  }

  @override
  String get reportsEmptyBody => 'Completed sales will appear here.';

  @override
  String get chatTitle => 'Smart Store Assistant';

  @override
  String get chatStatusOffline => 'On-device · Offline';

  @override
  String get chatStatusThinking => 'Thinking...';

  @override
  String get chatThinkingBubble => 'Looking at your store data...';

  @override
  String get chatInputHint => 'Ask about sales, stock, or utang...';

  @override
  String get chatSend => 'Send';

  @override
  String get chatVoice => 'Voice input';

  @override
  String chatSourcePrefix(String source) {
    return 'From: $source';
  }

  @override
  String get chatOpenTindaAi => 'Open Smart Store Assistant';

  @override
  String get chatSuggestionSales => 'How are sales today?';

  @override
  String get chatSuggestionLowStock => 'What is low on stock?';

  @override
  String get chatSuggestionUtang => 'Who has utang?';

  @override
  String get chatModelUnavailable =>
      'Smart Store Assistant model is offline fallback mode. Your sales continue normally.';

  @override
  String get chatErrorReply =>
      'Could not read store data right now. Your sales still continue normally.';

  @override
  String get chatSourceSales => 'Sales · On-device DB';

  @override
  String get chatSourceInventory => 'Inventory · On-device DB';

  @override
  String get chatSourceUtang => 'Utang Ledger · On-device DB';

  @override
  String get chatSourceSummary => 'Store Summary · On-device DB';

  @override
  String get chatReplySalesEmpty =>
      'No sales today yet. Once you record a sale, I will show total sales and profit here.';

  @override
  String chatReplySalesSummary(int count, String revenue, String profit) {
    return 'Today has $count sales: $revenue total sales and $profit profit.';
  }

  @override
  String chatReplyLowStockNone(int count) {
    return 'All $count products are stocked well — nothing is low right now.';
  }

  @override
  String chatReplyLowStockFound(int count, String names) {
    return '$count products are low on stock: $names.';
  }

  @override
  String get chatReplyUtangNone => 'No suki has utang right now.';

  @override
  String chatReplyUtangSummary(String total, int count, String topNames) {
    return 'Total utang: $total across $count suki. Highest: $topNames.';
  }

  @override
  String chatReplyOverview(
    String revenue,
    int count,
    int lowCount,
    String totalUtang,
  ) {
    return 'Store summary: $revenue sales today ($count transactions), $lowCount low on stock, and $totalUtang total utang.';
  }

  @override
  String get posScanUnavailable =>
      'Camera unavailable or permission denied. Enter the barcode manually below.';

  @override
  String get posScanTorchTooltip => 'Toggle flashlight';

  @override
  String get scannerManualHint => 'Or type barcode manually...';

  @override
  String get scannerUseCode => 'Use barcode';

  @override
  String scannerProductNotFound(String code) {
    return 'No product matches barcode $code.';
  }

  @override
  String get productStockDecrement => 'Decrease starting stock';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionBackup => 'BACKUP';

  @override
  String get settingsSectionAi => 'SMART STORE ASSISTANT';

  @override
  String get settingsSectionStore => 'STORE';

  @override
  String get settingsSectionPrivacy => 'PRIVACY';

  @override
  String get settingsSectionAbout => 'ABOUT';

  @override
  String get settingsSectionStorage => 'STORAGE & DATA';

  @override
  String get settingsStorageSizeLabel => 'Database size';

  @override
  String get settingsCompactButton => 'Compact storage';

  @override
  String settingsCompactDone(String size) {
    return 'Database compacted ($size).';
  }

  @override
  String get settingsNoBackupWarningTitle => 'No Google Drive backup yet';

  @override
  String get settingsNoBackupWarningBody =>
      'Data will be lost if you Clear Data in Android Settings or uninstall. Connect Google above to keep it safe.';

  @override
  String get settingsBackupNotConnected => 'Not connected yet';

  @override
  String get settingsBackupConnecting => 'Choosing account...';

  @override
  String get settingsBackupConnected => 'Connected';

  @override
  String get settingsBackupChooseTitle => 'Which data should we keep?';

  @override
  String get settingsBackupUsePhone => 'Use data on this phone';

  @override
  String get settingsBackupRestore => 'Restore backup';

  @override
  String get settingsBackupSyncNow => 'Sync now';

  @override
  String get settingsBackupDisconnect => 'Disconnect Google';

  @override
  String settingsBackupLastSync(String time) {
    return 'Last backup: $time';
  }

  @override
  String get settingsBackupJustNow => 'Just now';

  @override
  String get settingsBackupWifiOnly => 'Sync on Wi-Fi only';

  @override
  String get settingsAutoBackup => 'Auto-backup';

  @override
  String get settingsBackupFailed =>
      'Backup could not finish. Your data is still safe on your phone.';

  @override
  String get settingsAiOfflineBadge => '100% On-device · Offline';

  @override
  String get settingsPrivacyTracking => 'No tracking or ads';

  @override
  String get settingsPrivacyOfflineAi => 'AI runs offline on your phone';

  @override
  String get settingsPrivacyDataSafety =>
      'Your store data stays on your device.';

  @override
  String get settingsVersion => 'Version 1.0.0';

  @override
  String get settingsLanguageLabel => 'App language';

  @override
  String get settingsSwitchStore => 'Switch or add store';

  @override
  String get settingsAddStore => '+ New store';

  @override
  String get settingsDeleteStore => 'Delete store';

  @override
  String settingsDeleteStoreConfirm(String name) {
    return 'Delete $name? All its products, sales, and utang will be removed.';
  }

  @override
  String get settingsActiveBadge => 'Active';

  @override
  String get settingsLanguagePh => 'Filipino';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get unitPiece => 'piece';

  @override
  String get unitPack => 'pack';

  @override
  String get unitSachet => 'sachet';

  @override
  String get unitCan => 'can';

  @override
  String get unitBottle => 'bottle';

  @override
  String get unitBar => 'bar';

  @override
  String get unitBag => 'bag';

  @override
  String get unitKilo => 'kilo';

  @override
  String get unitLiter => 'liter';

  @override
  String get failureSaleNoLines => 'Add at least one product to the cart.';

  @override
  String get failureSaleQuantityInvalid => 'Enter a valid quantity.';

  @override
  String get failureSaleProductNotFound =>
      'That product is no longer available.';

  @override
  String get failureSaleCustomerRequired => 'Please choose a suki for utang.';

  @override
  String get failureSaleCustomerNotFound => 'That suki could not be found.';

  @override
  String get failureSalePaymentTooLow =>
      'Cash received is less than the total.';

  @override
  String get failureSaleStoreUnavailable =>
      'Could not save the sale. Your data is safe—try again.';

  @override
  String get failureProductNameRequired => 'Enter a product name.';

  @override
  String get failureProductAmountInvalid => 'Enter a valid price and cost.';

  @override
  String get failureProductQuantityInvalid => 'Enter a valid stock quantity.';

  @override
  String get failureProductBarcodeTaken =>
      'Another product already uses that barcode.';

  @override
  String get failureProductNotFound => 'Product not found.';

  @override
  String get failureProductStoreUnavailable =>
      'Could not save product. Try again.';

  @override
  String get failureCustomerNameRequired => 'Enter the suki\'s name.';

  @override
  String get failureCustomerNotFound => 'Suki not found.';

  @override
  String get failureCustomerAmountInvalid => 'Enter a valid amount.';

  @override
  String get failureCustomerPaymentExceedsBalance =>
      'Payment is more than the remaining balance.';

  @override
  String get failureCustomerStoreUnavailable =>
      'Could not save suki data. Try again.';

  @override
  String get failureStoreNameRequired => 'Enter your store\'s name.';

  @override
  String get failureStoreUnavailable =>
      'Could not save store profile. Try again.';

  @override
  String get settingsLocalBackupTitle => 'Local File Backup (.sqlite)';

  @override
  String get settingsLocalBackupSubtitle =>
      'Save a copy to your phone or restore from a .sqlite file.';

  @override
  String get settingsLocalExportButton => 'Export .sqlite';

  @override
  String get settingsLocalImportButton => 'Import .sqlite';

  @override
  String get settingsLocalExportSuccess => 'Backup file saved.';

  @override
  String get settingsLocalImportConfirmTitle => 'Import .sqlite backup?';

  @override
  String get settingsLocalImportConfirmBody =>
      'This will replace the current store data with the selected backup file.';

  @override
  String get settingsLocalImportSuccess => 'Backup restored from file.';

  @override
  String get settingsLocalImportInvalid =>
      'Invalid or corrupted Tinda360 backup file.';

  @override
  String get inventoryImportCsvTooltip => 'Import CSV';

  @override
  String get inventoryImportCsvTitle => 'Import Products (CSV)';

  @override
  String get inventoryImportCsvSubtitle =>
      'Columns: name, price, cost, stock, unit, barcode, low_stock';

  @override
  String get inventoryImportCsvPickButton => 'Choose CSV File';

  @override
  String get inventoryImportCsvTemplateButton => 'Save Sample CSV';

  @override
  String get inventoryImportCsvTemplateSaved => 'Sample CSV saved.';

  @override
  String inventoryImportCsvSuccess(int imported, int skipped) {
    return 'Imported $imported products ($skipped skipped).';
  }

  @override
  String get inventoryImportCsvEmpty =>
      'No valid products found in the CSV file.';

  @override
  String get inventoryImportCsvReadError =>
      'Could not read the selected CSV file.';

  @override
  String get ulatRecentSales => 'Recent Sales';

  @override
  String get ulatNoRecentSales => 'No sales in this period yet.';

  @override
  String ulatSaleItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get ulatSaleDetailTitle => 'Sale Receipt';

  @override
  String get ulatSaleTotalLabel => 'Total';

  @override
  String get ulatSalePaidLabel => 'Paid';

  @override
  String get ulatSaleReferenceLabel => 'Reference';

  @override
  String get ulatVoidSaleButton => 'Void / Delete Sale';

  @override
  String get ulatVoidSaleConfirmTitle => 'Void this sale?';

  @override
  String get ulatVoidSaleConfirmBody =>
      'This will remove the sale, restore product stock, and reverse any utang balance.';

  @override
  String get ulatVoidSaleSuccess => 'Sale voided and stock restored.';

  @override
  String get inventoryExportCsvButton => 'Export Products CSV';

  @override
  String get inventoryExportCsvSuccess => 'Products CSV saved.';

  @override
  String get reportsExportCsv => 'Export Sales CSV';

  @override
  String get reportsExportCsvSuccess => 'Sales CSV saved.';

  @override
  String get ulatExpensesTitle => 'Expenses';

  @override
  String get ulatAddExpenseButton => '+ Add Expense';

  @override
  String get ulatNoExpenses => 'No expenses in this period.';

  @override
  String get ulatNetIncomeLabel => 'Net income (after expenses)';

  @override
  String get ulatExpenseTitleLabel => 'Expense description';

  @override
  String get ulatExpenseAmountLabel => 'Amount';

  @override
  String get ulatExpenseSaved => 'Expense recorded.';

  @override
  String get settingsPinTitle => 'Store PIN Lock';

  @override
  String get settingsPinSubtitleOn => 'PIN required before voiding sales';

  @override
  String get settingsPinSubtitleOff =>
      'Protect sensitive actions with a 4-digit PIN';

  @override
  String get settingsPinSetButton => 'Set 4-Digit PIN';

  @override
  String get settingsPinRemoveButton => 'Remove PIN';

  @override
  String get settingsPinPromptTitle => 'Enter 4-Digit Store PIN';

  @override
  String get settingsPinSetSuccess => 'Store PIN saved.';

  @override
  String get settingsPinRemoved => 'Store PIN removed.';

  @override
  String get receiptPrint58mm => 'Print 58mm Receipt';

  @override
  String get receiptPreviewTitle => 'Receipt Preview';

  @override
  String get receiptPreviewPrint => 'Print';

  @override
  String get csvPreviewTitle => 'CSV Preview';

  @override
  String get csvPreviewExport => 'Export File';

  @override
  String csvPreviewRowCount(int count) {
    return '$count rows';
  }

  @override
  String csvPreviewMoreRows(int count) {
    return '... and $count more';
  }

  @override
  String chatWelcomeMessage(String greeting) {
    return '$greeting I\'m Yumi, your Smart Store Assistant. Ask me anything about your store\'s sales, stock, or utang!';
  }
}
