// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Filipino Pilipino (`fil`).
class AppLocalizationsFil extends AppLocalizations {
  AppLocalizationsFil([String locale = 'fil']) : super(locale);

  @override
  String get appTitle => 'Tinda 360';

  @override
  String get homeDatabaseReady => 'Handa na ang data ng tindahan';

  @override
  String homeProductCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produkto',
      one: '1 produkto',
      zero: 'Wala pang produkto',
    );
    return '$_temp0';
  }

  @override
  String homeLowStockCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produkto ang mababa ang stock',
      one: '1 produkto ang mababa ang stock',
      zero: 'Walang mababa ang stock',
    );
    return '$_temp0';
  }

  @override
  String get homeLoadFailed => 'Hindi mabuksan ang data ng tindahan.';

  @override
  String get commonRetry => 'Subukan ulit';

  @override
  String get commonClose => 'Isara';

  @override
  String get commonBack => 'Bumalik';

  @override
  String get commonSave => 'I-save';

  @override
  String get commonSwitch => 'Lumipat';

  @override
  String get commonCancel => 'Kanselahin';

  @override
  String get commonNext => 'Susunod';

  @override
  String get commonDelete => 'Burahin';

  @override
  String get commonAll => 'Lahat';

  @override
  String get commonSearch => 'Hanapin';

  @override
  String get splashPreparingAi => 'Inihahanda ang AI…';

  @override
  String get splashTagline => 'Smart POS na may AI, kahit offline';

  @override
  String get onboardingStep1Title => 'Ano ang pangalan ng tindahan mo?';

  @override
  String get onboardingStep1Subtitle => 'Lalabas ito sa mga ulat at resibo mo.';

  @override
  String get onboardingStoreNameLabel => 'Pangalan ng tindahan';

  @override
  String get onboardingStoreNameHint => 'hal. Tindahan ni Aling Nena';

  @override
  String get onboardingStep2Title => 'May backup ka na ba?';

  @override
  String get onboardingStep2Subtitle =>
      'Pwedeng magsimula nang bago o mag-restore mula sa Google Drive.';

  @override
  String get onboardingNewStoreTitle => 'Bagong tindahan ako';

  @override
  String get onboardingNewStoreSubtitle =>
      'Magsimula agad, offline sa phone mo.';

  @override
  String get onboardingSampleItemsToggle =>
      'Maglagay ng sample paninda para masubukan agad';

  @override
  String get onboardingRestoreTitle => 'I-restore ang backup';

  @override
  String get onboardingRestoreSubtitle =>
      'Ibalik ang mga produkto, benta, at utang.';

  @override
  String get onboardingGoogleButton => 'Magpatuloy gamit ang Google';

  @override
  String get onboardingRestoreUnavailable =>
      'Hindi pa naka-connect ang Google Drive restore. Pwede kang magsimula ngayon at mag-backup mamaya.';

  @override
  String get navSales => 'Benta';

  @override
  String get navInventory => 'Imbentaryo';

  @override
  String get navUtang => 'Utang';

  @override
  String get navReports => 'Ulat';

  @override
  String get posSearchHint => 'Hanapin ang produkto o barcode…';

  @override
  String get posScanBarcode => 'I-scan ang barcode';

  @override
  String get posOpenSettings => 'Settings';

  @override
  String get posGreeting =>
      'Magandang araw! Handa na sa benta. Pindutin ang produkto para idagdag.';

  @override
  String get posGreetingDismiss => 'Isara ang bati';

  @override
  String posAddToCart(String name) {
    return 'Idagdag ang $name';
  }

  @override
  String posRemoveFromCart(String name) {
    return 'Bawasan ang $name';
  }

  @override
  String posStockLabel(String qty) {
    return 'Stock $qty';
  }

  @override
  String get posLowStockBadge => 'Mababa';

  @override
  String posCartItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count item',
      one: '1 item',
    );
    return 'Cart · $_temp0';
  }

  @override
  String get posPayButton => 'Bayad';

  @override
  String get posEmptyTitle => 'Wala pang produkto';

  @override
  String get posEmptyBody =>
      'Magdagdag ng produkto sa Imbentaryo para makapagbenta.';

  @override
  String get posStorageFullTitle => 'Malapit nang mapuno ang storage';

  @override
  String get posStorageFullBody =>
      'Tuloy pa rin ang benta mo. Magbawas ng files para manatiling ligtas ang data.';

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get checkoutTotalLabel => 'Kabuuan';

  @override
  String get checkoutMethodCash => 'Cash';

  @override
  String get checkoutMethodEwallet => 'E-wallet';

  @override
  String get checkoutMethodUtang => 'Utang';

  @override
  String get checkoutTenderedLabel => 'Ibinayad na cash';

  @override
  String get checkoutChangeLabel => 'Sukli';

  @override
  String get checkoutEwalletRefLabel => 'Reference number (optional)';

  @override
  String get checkoutEwalletRefHint => 'Huling 4 na numero o ref no.';

  @override
  String get checkoutEwalletReminder =>
      'Siguraduhing pumasok na ang bayad bago tapusin ang benta.';

  @override
  String get checkoutSelectSuki => 'Piliin ang suki';

  @override
  String get checkoutNoSuki =>
      'Wala pang suki. Magdagdag muna ng suki sa Utang.';

  @override
  String get checkoutUtangNote => 'Idadagdag ang kabuuan sa balanse ng suki.';

  @override
  String get checkoutFinishSale => 'Tapusin ang benta';

  @override
  String get checkoutRecordUtang => 'Ilista sa utang';

  @override
  String get saleDoneTitle => 'Tapos na ang benta!';

  @override
  String get saleDoneTotal => 'Kabuuan';

  @override
  String get saleDonePaid => 'Bayad';

  @override
  String get saleDoneChange => 'Sukli';

  @override
  String get saleDoneNewSale => 'Bagong benta';

  @override
  String get saleDoneShareReceipt => 'I-share ang resibo';

  @override
  String get saleDoneReceiptCopied => 'Handa nang i-share ang resibo.';

  @override
  String get inventoryLowFilter => 'Mababa ang stock';

  @override
  String get inventoryAddProduct => '+ Produkto';

  @override
  String get inventoryEmptyTitle => 'Wala pang produkto';

  @override
  String get inventoryEmptyBody =>
      'Pindutin ang + Produkto para idagdag ang unang paninda.';

  @override
  String get inventoryFilterEmptyTitle => 'Walang nahanap na produkto';

  @override
  String get inventoryFilterEmptyBody => 'Subukan ang ibang salita o filter.';

  @override
  String inventorySummary(int total, int low) {
    return '$total produkto · $low mababa';
  }

  @override
  String get productSheetAddTitle => 'Magdagdag ng produkto';

  @override
  String get productSheetEditTitle => 'I-edit ang produkto';

  @override
  String get productNameLabel => 'Pangalan ng produkto';

  @override
  String get productNameHint => 'hal. Lucky Me Pancit Canton';

  @override
  String get productPriceLabel => 'Presyo ng benta (₱)';

  @override
  String get productCostLabel => 'Puhunan (₱)';

  @override
  String productProfitPerSale(String amount) {
    return 'Tubo kada benta: $amount';
  }

  @override
  String get productUnitLabel => 'Unit';

  @override
  String get productCategoryLabel => 'Kategorya (optional)';

  @override
  String get productInitialStockLabel => 'Simulang stock';

  @override
  String get productAdjustStockLabel => 'Ayusin ang stock';

  @override
  String productCurrentStockLabel(String qty) {
    return 'Stock ngayon: $qty';
  }

  @override
  String get productLowStockLabel => 'Alert level ng stock';

  @override
  String get productBarcodeLabel => 'Barcode (optional)';

  @override
  String get productDeleteButton => 'Burahin ang produkto';

  @override
  String get productDeleteConfirm =>
      'Alisin ang produktong ito sa mga aktibong paninda?';

  @override
  String get utangTitle => 'Utang';

  @override
  String get utangTotalLabel => 'Kabuuang utang';

  @override
  String utangSukiCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suki',
      one: '1 suki',
      zero: 'Walang suki',
    );
    return '$_temp0';
  }

  @override
  String get utangSearchHint => 'Hanapin ang suki…';

  @override
  String get utangPayButton => 'Bayad';

  @override
  String get utangAddSuki => '+ Suki';

  @override
  String get utangBalanceLabel => 'Balanse';

  @override
  String get utangOverLimit => 'Lagpas sa limit';

  @override
  String get utangEmptyTitle => 'Walang may utang';

  @override
  String get utangEmptyBody => 'Dito lalabas ang mga suki na may balanse.';

  @override
  String get utangPayTitle => 'Bayad sa utang';

  @override
  String get utangNewSukiTitle => 'Bagong suki';

  @override
  String get utangCurrentBalance => 'Kasalukuyang balanse';

  @override
  String get utangFullPayment => 'Buong bayad';

  @override
  String get utangPartialPayment => 'Bahagi lang';

  @override
  String get utangPaymentAmountLabel => 'Halaga ng bayad (₱)';

  @override
  String get utangNewBalanceLabel => 'Bagong balanse';

  @override
  String get utangRecordPayment => 'I-save ang bayad';

  @override
  String get utangSukiNameLabel => 'Pangalan ng suki';

  @override
  String get utangSukiPhoneLabel => 'Mobile number (optional)';

  @override
  String get utangSukiLimitLabel => 'Limit ng utang (optional)';

  @override
  String get utangSaveSuki => 'I-save ang suki';

  @override
  String get reportsTitle => 'Ulat';

  @override
  String get reportsToday => 'Ngayon';

  @override
  String get reportsWeek => 'Linggo';

  @override
  String get reportsMonth => 'Buwan';

  @override
  String get reportsSalesCard => 'Benta';

  @override
  String get reportsProfitCard => 'Tubo';

  @override
  String get reportsTransactionsCard => 'Transactions';

  @override
  String get reportsNewUtangCard => 'Bagong utang';

  @override
  String get reportsChartTitle => 'Takbo ng benta';

  @override
  String reportsChartTitlePeriod(String period) {
    return 'Takbo ng benta · $period';
  }

  @override
  String get reportsTopProductsTitle => 'Top 3 na produkto';

  @override
  String reportsTopProductSold(String qty, String amount) {
    return '$qty nabenta · $amount';
  }

  @override
  String get reportsAskAi => 'Itanong sa Smart Store Assistant ang ulat na ito';

  @override
  String get reportsExportPdf => 'I-export bilang PDF';

  @override
  String get reportsExportPdfError => 'Hindi magawa ang PDF report.';

  @override
  String get reportsEmptyTitle => 'Wala pang benta rito';

  @override
  String reportsEmptyTitlePeriod(String period) {
    return 'Wala pang benta ($period)';
  }

  @override
  String get reportsEmptyBody => 'Lalabas dito ang mga natapos na benta.';

  @override
  String get chatTitle => 'Smart Store Assistant';

  @override
  String get chatStatusOffline => 'On-device · Offline';

  @override
  String get chatStatusThinking => 'Nag-iisip…';

  @override
  String get chatThinkingBubble => 'Tinitingnan ko ang data mo…';

  @override
  String get chatInputHint => 'Magtanong tungkol sa benta, stock, o utang…';

  @override
  String get chatSend => 'Ipadala';

  @override
  String get chatVoice => 'Gamitin ang boses';

  @override
  String chatSourcePrefix(String source) {
    return 'Galing sa: $source';
  }

  @override
  String get chatOpenTindaAi => 'Buksan ang Smart Store Assistant';

  @override
  String get chatSuggestionSales => 'Magkano ang benta ngayon?';

  @override
  String get chatSuggestionLowStock => 'Ano ang mababa ang stock?';

  @override
  String get chatSuggestionUtang => 'Sino ang may utang?';

  @override
  String get chatModelUnavailable =>
      'Naka-offline fallback ang Smart Store Assistant. Tuloy pa rin ang benta mo.';

  @override
  String get chatErrorReply =>
      'Hindi mabasa ang data ng tindahan ngayon. Tuloy pa rin ang benta mo.';

  @override
  String get chatSourceSales => 'Benta · On-device DB';

  @override
  String get chatSourceInventory => 'Imbentaryo · On-device DB';

  @override
  String get chatSourceUtang => 'Listahan ng Utang · On-device DB';

  @override
  String get chatSourceSummary => 'Buod ng Tindahan · On-device DB';

  @override
  String get chatReplySalesEmpty =>
      'Wala pang benta ngayon. Kapag may nakabenta ka na, ipapakita ko rito ang kabuuang benta at tubo.';

  @override
  String chatReplySalesSummary(int count, String revenue, String profit) {
    return 'Ngayon ay may $count na benta: $revenue ang kabuuang benta at $profit ang tubo.';
  }

  @override
  String chatReplyLowStockNone(int count) {
    return 'Maayos ang lahat ng $count produkto — walang mababa ang stock ngayon.';
  }

  @override
  String chatReplyLowStockFound(int count, String names) {
    return 'May $count produktong mababa ang stock: $names.';
  }

  @override
  String get chatReplyUtangNone =>
      'Walang may utang ngayon. Bayad lahat ng suki!';

  @override
  String chatReplyUtangSummary(String total, int count, String topNames) {
    return 'Kabuuang utang: $total mula sa $count suki. Pinakamataas: $topNames.';
  }

  @override
  String chatReplyOverview(
    String revenue,
    int count,
    int lowCount,
    String totalUtang,
  ) {
    return 'Buod ng tindahan: $revenue benta ngayon ($count transactions), $lowCount mababa ang stock, at $totalUtang kabuuang utang.';
  }

  @override
  String get posScanUnavailable =>
      'Walang camera o walang permission. I-type na lang ang barcode sa ibaba.';

  @override
  String get posScanTorchTooltip => 'Buksan o isara ang flashlight';

  @override
  String get scannerManualHint => 'O i-type ang barcode dito…';

  @override
  String get scannerUseCode => 'Gamitin ang barcode';

  @override
  String scannerProductNotFound(String code) {
    return 'Walang produktong may barcode na $code.';
  }

  @override
  String get productStockDecrement => 'Bawasan ang simulang stock';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionBackup => 'BACKUP';

  @override
  String get settingsSectionAi => 'SMART STORE ASSISTANT';

  @override
  String get settingsSectionStore => 'TINDAHAN';

  @override
  String get settingsSectionPrivacy => 'PRIVACY';

  @override
  String get settingsSectionAbout => 'TUNGKOL SA APP';

  @override
  String get settingsSectionStorage => 'STORAGE AT DATA';

  @override
  String get settingsStorageSizeLabel => 'Laki ng database';

  @override
  String get settingsCompactButton => 'Paliitin ang storage (Compact)';

  @override
  String settingsCompactDone(String size) {
    return 'Na-compact ang database ($size).';
  }

  @override
  String get settingsNoBackupWarningTitle => 'Walang Google Drive backup';

  @override
  String get settingsNoBackupWarningBody =>
      'Mawawala ang data kapag nag-Clear Data sa Android Settings o nag-uninstall. Mag-connect sa Google sa itaas para ligtas.';

  @override
  String get settingsBackupNotConnected => 'Hindi pa naka-connect';

  @override
  String get settingsBackupConnecting => 'Pumipili ng account…';

  @override
  String get settingsBackupConnected => 'Naka-connect';

  @override
  String get settingsBackupChooseTitle => 'Aling data ang gagamitin?';

  @override
  String get settingsBackupUsePhone => 'Gamitin ang data sa phone';

  @override
  String get settingsBackupRestore => 'I-restore ang backup';

  @override
  String get settingsBackupSyncNow => 'Sync ngayon';

  @override
  String get settingsBackupDisconnect => 'I-disconnect ang Google';

  @override
  String settingsBackupLastSync(String time) {
    return 'Huling backup: $time';
  }

  @override
  String get settingsBackupJustNow => 'Ngayon lang';

  @override
  String get settingsBackupWifiOnly => 'Sa Wi-Fi lang mag-sync';

  @override
  String get settingsAutoBackup => 'Auto-backup';

  @override
  String get settingsBackupFailed =>
      'Hindi natapos ang backup. Ligtas pa rin ang data sa phone.';

  @override
  String get settingsAiOfflineBadge => '100% On-device · Offline';

  @override
  String get settingsPrivacyTracking => 'Walang tracking o ads';

  @override
  String get settingsPrivacyOfflineAi => 'Offline ang AI sa phone mo';

  @override
  String get settingsPrivacyDataSafety => 'Ligtas pa rin ang data sa phone.';

  @override
  String get settingsVersion => 'Version 1.0.0';

  @override
  String get settingsLanguageLabel => 'Wika ng app';

  @override
  String get settingsSwitchStore => 'Lumipat o magdagdag ng tindahan';

  @override
  String get settingsAddStore => '+ Bagong tindahan';

  @override
  String get settingsDeleteStore => 'Burahin ang tindahan';

  @override
  String settingsDeleteStoreConfirm(String name) {
    return 'Sigurado ka bang buburahin ang $name? Mawawala lahat ng produkto, benta, at utang nito.';
  }

  @override
  String settingsSwitchStoreConfirm(String name) {
    return 'Lumipat sa $name? Mananatiling naka-save ang kasalukuyang tindahan mo.';
  }

  @override
  String get settingsActiveBadge => 'Aktibo';

  @override
  String get settingsLanguagePh => 'Filipino';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get unitPiece => 'piraso';

  @override
  String get unitPack => 'pack';

  @override
  String get unitSachet => 'sachet';

  @override
  String get unitCan => 'lata';

  @override
  String get unitBottle => 'bote';

  @override
  String get unitBar => 'bareta';

  @override
  String get unitBag => 'supot';

  @override
  String get unitKilo => 'kilo';

  @override
  String get unitLiter => 'litro';

  @override
  String get failureSaleNoLines =>
      'Maglagay muna ng kahit isang produkto sa cart.';

  @override
  String get failureSaleQuantityInvalid => 'Maglagay ng tamang dami.';

  @override
  String get failureSaleProductNotFound => 'Wala na ang produktong iyon.';

  @override
  String get failureSaleCustomerRequired => 'Pumili ng suki para sa utang.';

  @override
  String get failureSaleCustomerNotFound => 'Hindi mahanap ang suki.';

  @override
  String get failureSalePaymentTooLow =>
      'Kulang ang ibinigay na cash para sa kabuuan.';

  @override
  String get failureSaleStoreUnavailable =>
      'Hindi na-save ang benta. Ligtas pa rin ang data sa phone—subukan ulit.';

  @override
  String get failureProductNameRequired => 'Ilagay ang pangalan ng produkto.';

  @override
  String get failureProductAmountInvalid =>
      'Maglagay ng tamang presyo at puhunan.';

  @override
  String get failureProductQuantityInvalid =>
      'Maglagay ng tamang dami ng stock.';

  @override
  String get failureProductBarcodeTaken =>
      'May ibang produkto nang gumagamit ng barcode na iyon.';

  @override
  String get failureProductNotFound => 'Hindi mahanap ang produkto.';

  @override
  String get failureProductStoreUnavailable =>
      'Hindi na-save ang produkto. Subukan ulit.';

  @override
  String get failureCustomerNameRequired => 'Ilagay ang pangalan ng suki.';

  @override
  String get failureCustomerNotFound => 'Hindi mahanap ang suki.';

  @override
  String get failureCustomerAmountInvalid => 'Maglagay ng tamang halaga.';

  @override
  String get failureCustomerPaymentExceedsBalance =>
      'Mas malaki ang bayad kaysa sa natitirang balanse.';

  @override
  String get failureCustomerStoreUnavailable =>
      'Hindi na-save ang data ng suki. Subukan ulit.';

  @override
  String get failureStoreNameRequired => 'Ilagay ang pangalan ng tindahan.';

  @override
  String get failureStoreUnavailable =>
      'Hindi na-save ang profile ng tindahan. Subukan ulit.';

  @override
  String get settingsLocalBackupTitle => 'Lokal na Backup (.sqlite)';

  @override
  String get settingsLocalBackupSubtitle =>
      'Mag-save ng kopya sa phone o mag-restore mula sa .sqlite file.';

  @override
  String get settingsLocalExportButton => 'I-export .sqlite';

  @override
  String get settingsLocalImportButton => 'I-import .sqlite';

  @override
  String get settingsLocalExportSuccess => 'Na-save ang backup file.';

  @override
  String get settingsLocalImportConfirmTitle => 'I-import ang .sqlite backup?';

  @override
  String get settingsLocalImportConfirmBody =>
      'Papalitan nito ang kasalukuyang data ng tindahan ng napiling backup file.';

  @override
  String get settingsLocalImportSuccess =>
      'Na-restore ang backup mula sa file.';

  @override
  String get settingsLocalImportInvalid =>
      'Hindi wasto o sira ang Tinda360 backup file.';

  @override
  String get inventoryImportCsvTooltip => 'Mag-import ng CSV';

  @override
  String get inventoryImportCsvTitle => 'Mag-import ng Produkto (CSV)';

  @override
  String get inventoryImportCsvSubtitle =>
      'Mga column: name, price, cost, stock, unit, barcode, low_stock';

  @override
  String get inventoryImportCsvPickButton => 'Pumili ng CSV File';

  @override
  String get inventoryImportCsvTemplateButton => 'I-save ang Sample CSV';

  @override
  String get inventoryImportCsvTemplateSaved => 'Na-save ang sample CSV.';

  @override
  String inventoryImportCsvSuccess(int imported, int skipped) {
    return 'Na-import ang $imported produkto ($skipped nilaktawan).';
  }

  @override
  String get inventoryImportCsvEmpty => 'Walang wastong produkto sa CSV file.';

  @override
  String get inventoryImportCsvReadError =>
      'Hindi mabasa ang napiling CSV file.';

  @override
  String get ulatRecentSales => 'Mga Kamakailang Benta';

  @override
  String get ulatNoRecentSales => 'Wala pang benta sa panahong ito.';

  @override
  String ulatSaleItemsCount(int count) {
    return '$count item';
  }

  @override
  String get ulatSaleDetailTitle => 'Resibo ng Benta';

  @override
  String get ulatSaleTotalLabel => 'Kabuuan';

  @override
  String get ulatSalePaidLabel => 'Binayad';

  @override
  String get ulatSaleReferenceLabel => 'Reference';

  @override
  String get ulatVoidSaleButton => 'I-void / Burahin ang Benta';

  @override
  String get ulatVoidSaleConfirmTitle => 'I-void ang bentang ito?';

  @override
  String get ulatVoidSaleConfirmBody =>
      'Mabubura ang benta, maibabalik ang stock ng produkto, at maaalis ang utang kung mayroon.';

  @override
  String get ulatVoidSaleSuccess => 'Na-void ang benta at naibalik ang stock.';

  @override
  String get inventoryExportCsvButton => 'I-export ang Produkto (CSV)';

  @override
  String get inventoryExportCsvSuccess => 'Na-save ang Products CSV.';

  @override
  String get reportsExportCsv => 'I-export ang Benta (CSV)';

  @override
  String get reportsExportCsvSuccess => 'Na-save ang Sales CSV.';

  @override
  String get ulatExpensesTitle => 'Mga Gastos';

  @override
  String get ulatAddExpenseButton => '+ Magdagdag ng Gastos';

  @override
  String get ulatNoExpenses => 'Walang gastos sa panahong ito.';

  @override
  String get ulatNetIncomeLabel => 'Netong kita (bawas gastos)';

  @override
  String get ulatExpenseTitleLabel => 'Para saan ang gastos';

  @override
  String get ulatExpenseAmountLabel => 'Halaga';

  @override
  String get ulatExpenseSaved => 'Naitala ang gastos.';

  @override
  String get settingsPinTitle => '4-Digit Store PIN';

  @override
  String get settingsPinSubtitleOn => 'Hihingi ng PIN bago mag-void ng benta';

  @override
  String get settingsPinSubtitleOff =>
      'Protektahan ng 4-digit PIN ang mga sensitibong aksyon';

  @override
  String get settingsPinSetButton => 'Maglagay ng PIN';

  @override
  String get settingsPinRemoveButton => 'Tanggalin ang PIN';

  @override
  String get settingsPinPromptTitle => 'Ilagay ang 4-Digit PIN';

  @override
  String get settingsPinSetSuccess => 'Na-save ang Store PIN.';

  @override
  String get settingsPinRemoved => 'Natanggal ang Store PIN.';

  @override
  String get receiptPrint58mm => 'I-print (58mm Receipt)';

  @override
  String get receiptPreviewTitle => 'Preview ng Resibo';

  @override
  String get receiptPreviewPrint => 'I-print';

  @override
  String get csvPreviewTitle => 'Preview ng CSV';

  @override
  String get csvPreviewExport => 'I-export ang File';

  @override
  String csvPreviewRowCount(int count) {
    return '$count na hilera';
  }

  @override
  String csvPreviewMoreRows(int count) {
    return '... at $count pa';
  }

  @override
  String chatWelcomeMessage(String greeting) {
    return '$greeting Ako si Yumi, ang iyong Smart Store Assistant. Halika, magtanong tungkol sa benta, stock, o utang ng tindahan mo!';
  }
}
