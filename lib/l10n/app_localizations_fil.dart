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
  String posOutOfStock(String name) {
    return 'Wala nang stock ang $name.';
  }

  @override
  String get posLowStockBadge => 'Mababa';

  @override
  String get posOutOfStockBadge => 'Ubos na';

  @override
  String get checkoutExactAmountChip => 'Eksakto';

  @override
  String get posBackupStaleTitle => 'Wala pang backup sa loob ng 7 araw';

  @override
  String get posBackupNeverTitle => 'I-backup ang data mo para hindi mawala';

  @override
  String get posBackupWarningBody =>
      'I-tap para buksan ang Settings at mag-backup na.';

  @override
  String get posQuantityMode => 'Dami';

  @override
  String get posAmountMode => 'Halaga (₱)';

  @override
  String posAmountEquals(String quantity) {
    return '= $quantity';
  }

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
  String get checkoutPaidNowLabel => 'Bayad ngayon (₱, optional)';

  @override
  String checkoutPaidNowRemaining(String amount) {
    return 'Utang sa bentang ito: $amount';
  }

  @override
  String get checkoutPaidNowInvalid =>
      'Ang bayad ngayon ay dapat ₱0 hanggang sa total.';

  @override
  String checkoutPriceDialogTitle(String product) {
    return 'Presyo ng $product';
  }

  @override
  String checkoutPriceNormal(String price) {
    return 'Normal na presyo: $price';
  }

  @override
  String get checkoutPriceLabel => 'Presyo ng bawat isa ngayon (₱)';

  @override
  String get checkoutPriceInvalid => 'Maglagay ng presyong ₱0 o higit pa.';

  @override
  String get checkoutPriceReset => 'Ibalik sa normal na presyo';

  @override
  String get failureSalePaidNowInvalid =>
      'Dapat ₱0 hanggang kabuuan ang bayad ngayon.';

  @override
  String get failureSalePriceInvalid => 'Hindi puwedeng negatibo ang presyo.';

  @override
  String get receiptNumberLabel => 'Resibo no.';

  @override
  String get receiptSukiLabel => 'Suki';

  @override
  String get receiptReferenceLabel => 'Ref';

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
  String get saleDoneShareFailed =>
      'Hindi mabuksan ang pag-share. Subukan ulit.';

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
  String get productNoCountSwitch => 'Huwag bilangin ang stock';

  @override
  String get productNoCountHint =>
      'Para sa load, tingi at iba pang hindi binibilang.';

  @override
  String get productExpiryLabel => 'Petsa ng expiry (optional)';

  @override
  String get productExpiryClear => 'Alisin ang petsa ng expiry';

  @override
  String get productDuplicateNameWarning => 'May kapareho nang pangalan.';

  @override
  String get productPriceZeroWarning => 'Zero ang presyo. Tama ba?';

  @override
  String get inventoryNoCountLabel => 'Walang bilang';

  @override
  String inventoryExpiryDaysBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mag-expire sa $count araw',
      one: 'Mag-expire sa 1 araw',
      zero: 'Mag-expire ngayon',
    );
    return '$_temp0';
  }

  @override
  String get inventoryExpiredBadge => 'Expired';

  @override
  String get inventoryExpiringFilter => 'Malapit mag-expire';

  @override
  String get inventoryShareShoppingList => 'Ibahagi ang listahan ng bibilhin';

  @override
  String get shoppingListHeader => 'Bibilhin:';

  @override
  String shoppingListLine(String name, String amount, String unit) {
    return '- $name: bumili ng $amount $unit';
  }

  @override
  String get productRestockCostLabel =>
      'Bagong puhunan kada piraso (₱), optional';

  @override
  String get productStockHistoryButton => 'Galaw ng stock';

  @override
  String get stockHistoryTitle => 'Galaw ng stock';

  @override
  String get stockHistoryEmpty => 'Wala pang galaw ang stock.';

  @override
  String stockHistoryAfter(String stock) {
    return 'Natira: $stock';
  }

  @override
  String get stockReasonInitial => 'Unang stock';

  @override
  String get stockReasonRestock => 'Restock';

  @override
  String get stockReasonAdjust => 'Inayos';

  @override
  String get stockReasonReturn => 'Isinauli';

  @override
  String get receiptRefunded => 'Naibalik';

  @override
  String get receiptNetTotal => 'Netong kabuuan';

  @override
  String get checkoutCreditNearTitle => 'Malapit na sa limit ng utang';

  @override
  String checkoutCreditNearBody(String name, String balance, String limit) {
    return 'Si $name ay may $balance na utang na hindi pa bayad (limit: $limit).';
  }

  @override
  String get reportsExportCsvError => 'Hindi ma-export ang CSV file.';

  @override
  String get ledgerDeleteConfirmTitle => 'Burahin ang linyang ito?';

  @override
  String ledgerDeleteConfirmBody(String kind, String amount, String date) {
    return '$kind $amount noong $date. Mananatili ito sa listahan na binura, at aayusin ang balanse.';
  }

  @override
  String get ledgerDeleteReasonLabel => 'Dahilan (optional)';

  @override
  String get ledgerDeleteConfirmAction => 'Burahin';

  @override
  String get ledgerDeleteDone => 'Nabura na ang linya.';

  @override
  String ledgerDeletedWithReason(String reason) {
    return 'Binura: $reason';
  }

  @override
  String get ledgerDeletedNoReason => 'Binura';

  @override
  String get ledgerNotDeletableHint => 'Galing sa benta. I-void ang benta.';

  @override
  String get failureLedgerEntryNotFound => 'Hindi makita ang linyang ito.';

  @override
  String get failureLedgerEntryAlreadyDeleted => 'Nabura na ang linyang ito.';

  @override
  String get failureLedgerEntryNotDeletable =>
      'Hindi ito mabubura dito. I-void ang benta.';

  @override
  String get failureLedgerDeleteWouldGoNegative =>
      'Hindi mabubura ang interes na ito. Sobra na ang bayad sa balanse.';

  @override
  String get checkoutInterestLabel => 'Interes';

  @override
  String get checkoutInterestPrompt => 'Tutubuan ba? Optional lang.';

  @override
  String get checkoutInterestPercentInvalid =>
      'Maglagay ng 0.1 hanggang 50.0 na porsyento, tulad ng 5 o 2.5.';

  @override
  String get checkoutInterestAmountInvalid =>
      'Maglagay ng tamang halaga sa peso, higit sa zero.';

  @override
  String get checkoutInterestTooMuch =>
      'Hindi puwedeng mas malaki ang interes kaysa sa utang.';

  @override
  String checkoutInterestPreview(String utang, String interest, String total) {
    return 'Utang $utang + interes $interest = $total';
  }

  @override
  String get receiptInterest => 'Interes';

  @override
  String get failureSaleInterestInvalid =>
      'Dapat higit sa zero ang interes, at para lang sa utang na may suki.';

  @override
  String get productUtangPriceLabel => 'Presyo kapag utang (₱, optional)';

  @override
  String get checkoutUtangPriceTag => 'Presyong utang';

  @override
  String get failureCustomerInterestAmountChanged =>
      'Nagbago ang utang, kaya nagbago rin ang interes. Tingnan ulit at subukan uli.';

  @override
  String checkoutShortfallPrompt(String amount) {
    return 'Kulang ang bayad. Ilista ang kulang na $amount sa utang? Pumili ng suki sa baba.';
  }

  @override
  String get yumiChipLowStock => 'Ano ang mababa sa stock?';

  @override
  String get yumiChipSalesToday => 'Magkano ang benta ngayon?';

  @override
  String get yumiChipProductCount => 'Ilan ang produkto ko?';

  @override
  String get yumiChipSlowMoving => 'Ano ang matumal?';

  @override
  String get yumiChipWhoHasUtang => 'Sino ang may utang?';

  @override
  String get yumiChipUtangRisk => 'Delikado ba ang utang?';

  @override
  String get yumiChipExpensesWeek => 'Magkano ang gastos ngayong linggo?';

  @override
  String get yumiChipCompareYesterday => 'Kumpara sa kahapon';

  @override
  String get yumiChipWhatCanYouDo => 'What can you do?';

  @override
  String get yumiHintPos =>
      'Nasa Benta ka. Tanungin mo ako kung ano ang mababa sa stock o kumusta ang benta.';

  @override
  String get yumiHintInventory =>
      'Nasa Imbentaryo ka. Tanungin mo ako kung ano ang mababa o matumal.';

  @override
  String get yumiHintUtang =>
      'Nasa Utang ka. Tanungin mo ako kung sino ang may utang at magkano.';

  @override
  String get yumiHintReports =>
      'Nasa Ulat ka. Tanungin mo ako tungkol sa benta, gastos, o kahapon.';

  @override
  String get yumiHintSettings =>
      'Nasa Settings ka. Tanungin mo ako kung ano ang kaya kong gawin.';

  @override
  String get sukiTuboLabel => 'Interes % (hindi kailangan)';

  @override
  String get sukiTuboHint => 'hal. 5 o 2.5';

  @override
  String get sukiTuboInvalid =>
      'Ang interes ay dapat 0.1 hanggang 50.0 porsyento.';

  @override
  String get ledgerKindTubo => 'Interes';

  @override
  String get ledgerAddTubo => 'Dagdag interes';

  @override
  String get ledgerTuboConfirmTitle => 'Dagdagan ng interes?';

  @override
  String ledgerTuboConfirmBody(String balance, String percent, String amount) {
    return '$balance + $percent% = $amount interes';
  }

  @override
  String get ledgerTuboConfirmAction => 'Dagdag interes';

  @override
  String ledgerTuboAdded(String amount) {
    return 'Nadagdag na ang interes na $amount.';
  }

  @override
  String ledgerReminderTuboMessage(
    String customerName,
    String storeName,
    String utang,
    String tubo,
    String total,
  ) {
    return 'Magandang araw, $customerName! Paalala po mula sa $storeName: Utang $utang + interes $tubo = $total. Salamat po!';
  }

  @override
  String get failureCustomerInterestRateNotSet =>
      'Walang interes na naka-set para sa suki na ito.';

  @override
  String get failureCustomerInterestNoBalance =>
      'Walang utang, kaya walang madadagdagan ng interes.';

  @override
  String get stockReasonSale => 'Benta';

  @override
  String get reportPdfMetricHeader => 'Sukat';

  @override
  String get reportPdfValueHeader => 'Halaga';

  @override
  String get reportPdfProductHeader => 'Produkto';

  @override
  String get reportPdfQuantitySoldHeader => 'Dami ng Nabenta';

  @override
  String get reportPdfRevenueHeader => 'Benta';

  @override
  String reportPdfPreparedBy(String storeName) {
    return '$storeName - Inihanda ng May-ari ng Tindahan';
  }

  @override
  String get sukiEditAction => 'I-edit';

  @override
  String get sukiDeleteAction => 'Burahin';

  @override
  String get sukiEditTitle => 'I-edit ang suki';

  @override
  String get sukiSaveChanges => 'I-save ang changes';

  @override
  String get sukiDeleteConfirmTitle => 'Burahin ang suki?';

  @override
  String sukiDeleteConfirmBody(String name) {
    return 'Aalisin si $name sa listahan ng suki. Puwede lang ito kapag zero na ang balanse.';
  }

  @override
  String get failureCustomerHasBalance =>
      'Hindi mabubura ang suki na may utang pa.';

  @override
  String get ledgerShareReminder => 'I-share ang paalala';

  @override
  String get ledgerCopyReminder => 'Kopyahin';

  @override
  String get ledgerEmptyEntries => 'Wala pang nakasulat sa listahan.';

  @override
  String get ledgerKindUtang => 'Utang';

  @override
  String get ledgerKindPayment => 'Bayad';

  @override
  String get ledgerReminderDefaultStore => 'aming tindahan';

  @override
  String ledgerReminderMessage(
    String customerName,
    String storeName,
    String balance,
  ) {
    return 'Magandang araw, $customerName! Paalala po mula sa $storeName: ang utang mo ay $balance. Salamat po!';
  }

  @override
  String inventoryCostSummary(String amount) {
    return 'Puhunan $amount';
  }

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
  String get utangCurrentBalance => 'Utang ngayon';

  @override
  String utangAgeDays(int count) {
    return '$count araw na';
  }

  @override
  String get utangExportCsv => 'I-export ang utang (CSV)';

  @override
  String checkoutCreditLimitExceeded(String limit) {
    return 'Lampas na sa limit ng utang ($limit)';
  }

  @override
  String get checkoutCreditLimitOverride => 'Pahintulutan ng may-ari';

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
  String get reportsTransactionsCard => 'Mga transaksyon';

  @override
  String get reportsNewUtangCard => 'Natitirang utang';

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
  String get chatStatusOffline => 'Sa phone · Offline';

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
  String get settingsSectionAi => 'MATALINONG KATULONG SA TINDAHAN';

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
  String get settingsAiOfflineBadge => '100% sa phone · Offline';

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
  String get settingsAddStoreFailed =>
      'Hindi maidagdag ang store. Subukan ulit.';

  @override
  String get settingsLocalBackupFailed =>
      'Hindi natapos ang backup file. Subukan ulit.';

  @override
  String get ulatExpenseDeleteFailed =>
      'Hindi mabura ang gastos. Subukan ulit.';

  @override
  String pinLockedOut(int seconds) {
    return 'Sobrang daming maling subok. Maghintay ng $seconds segundo.';
  }

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
  String get failureSaleNotFound => 'Na-void na o wala na ang bentang ito.';

  @override
  String get failureSaleVoidAfterPayment =>
      'Hindi ma-void: may naibayad na ang suki sa utang na ito.';

  @override
  String get failureSaleInsufficientStock =>
      'Kulang ang stock ng isang item sa cart.';

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
  String scannerScannedCount(int count) {
    return 'Na-scan: $count';
  }

  @override
  String get ulatShareButton => 'Ibahagi ang ulat (text)';

  @override
  String get ulatShareRevenueLabel => 'Benta';

  @override
  String get ulatShareProfitLabel => 'Tubo';

  @override
  String get ulatShareTransactionsLabel => 'Mga transaksyon';

  @override
  String get ulatShareExpensesLabel => 'Gastos';

  @override
  String get ulatShareNetIncomeLabel => 'Netong kita';

  @override
  String get ulatShareUtangLabel => 'Natitirang utang';

  @override
  String get ulatShareTopProductsLabel => 'Top 3 produkto';

  @override
  String ulatShareCashCountLine(
    String expected,
    String counted,
    String difference,
  ) {
    return 'Bilang ng pera: Dapat $expected · Binilang $counted · $difference';
  }

  @override
  String get reportsCustom => 'Pasadya';

  @override
  String get reportsThisMonth => 'Ngayong buwan';

  @override
  String get reportsLastMonth => 'Nakaraang buwan';

  @override
  String get reportsPickDates => 'Pumili ng petsa';

  @override
  String get reportsRangeInvalid =>
      'Pumili ng hanggang 366 araw, hanggang ngayon lang.';

  @override
  String reportsRangeLabel(String start, String end) {
    return '$start – $end';
  }

  @override
  String get cashCountTitle => 'Bilangin ang kaha ngayong araw';

  @override
  String get cashCountExpectedLabel => 'Dapat laman ng kaha';

  @override
  String get cashCountCountedLabel => 'Pera na nabilang mo';

  @override
  String get cashCountNoteLabel => 'Tala (opsyonal)';

  @override
  String get cashCountSaveButton => 'I-save ang bilang';

  @override
  String get cashCountSaved => 'Na-save na ang bilang ng kaha.';

  @override
  String get cashCountInvalidAmount => 'Ilagay kung magkano ang nabilang mo.';

  @override
  String get cashCountSaveFailed => 'Hindi ma-save ang bilang. Subukan ulit.';

  @override
  String cashCountOver(String amount) {
    return 'Sobra ng $amount';
  }

  @override
  String cashCountShort(String amount) {
    return 'Kulang ng $amount';
  }

  @override
  String get cashCountExact => 'Tama';

  @override
  String get cashCountTodayHeading => 'Bilang ngayong araw';

  @override
  String get cashCountHistoryHeading => 'Nakaraang 7 araw';

  @override
  String cashCountRowSummary(String counted, String expected) {
    return 'Nabilang $counted · Dapat $expected';
  }

  @override
  String get cashCountNoHistory => 'Wala pang bilang ng kaha.';

  @override
  String get ulatSaleReferenceLabel => 'Reference';

  @override
  String get ulatVoidSaleButton => 'I-void / Burahin ang Benta';

  @override
  String get receiptBantayLabel => 'Bantay';

  @override
  String get bantayChipEmpty => 'Ilagay ang Bantay';

  @override
  String bantayChipLabel(String name) {
    return 'Bantay: $name';
  }

  @override
  String get bantayDialogTitle => 'Sino ang bantay ng tindahan?';

  @override
  String get bantayFieldHint => 'Pangalan (optional)';

  @override
  String get settingsAddressLabel => 'Address';

  @override
  String get settingsPhoneLabel => 'Telepono';

  @override
  String ledgerDeletedByNoReason(String name) {
    return 'Binura ni $name';
  }

  @override
  String ledgerDeletedByWithReason(String name, String reason) {
    return 'Binura ni $name: $reason';
  }

  @override
  String get ulatReturnTitle => 'Isauli ang item';

  @override
  String ulatReturnAvailable(String quantity) {
    return 'Pwedeng isauli: $quantity';
  }

  @override
  String get ulatReturnQuantityLabel => 'Ilan ang isasauli';

  @override
  String get ulatReturnReasonLabel => 'Dahilan (opsyonal)';

  @override
  String get ulatReturnRefundTotal => 'Isasauli na pera';

  @override
  String get ulatReturnConfirmButton => 'I-save ang pagsauli';

  @override
  String get ulatReturnNothingReturnable =>
      'Naisauli na lahat ng item sa benta na ito.';

  @override
  String ulatReturnSuccessCash(String amount) {
    return 'Isauli ang $amount sa customer';
  }

  @override
  String ulatReturnSuccessUtang(String amount) {
    return 'Binawas ang $amount sa utang ng customer';
  }

  @override
  String ulatReturnSuccessUtangPartial(String credit, String cash) {
    return 'Binawas ang $credit sa utang. Ibalik ang $cash na pera sa customer.';
  }

  @override
  String get failureSaleVoidAfterReturn =>
      'May naibalik nang item sa bentang ito kaya hindi ito mai-void.';

  @override
  String get failureSaleReturnNothingSelected =>
      'Maglagay ng dami na ibabalik.';

  @override
  String get failureSaleReturnQuantityInvalid =>
      'Hindi tama ang dami ng ibabalik.';

  @override
  String get failureSaleReturnTooMany => 'Hindi pwedeng lumampas sa naibenta.';

  @override
  String get failureSaleReturnSaleVoided =>
      'Na-void na ang bentang ito kaya wala nang maibabalik.';

  @override
  String get failureSaleReturnNotFound => 'Hindi nahanap ang benta.';

  @override
  String get failureSaleReturnStoreUnavailable =>
      'Hindi na-save ang balik. Subukan ulit.';

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

  @override
  String get pinRecoveryTitle => 'I-save ang Recovery Code';

  @override
  String get pinRecoveryBody =>
      'Isulat o kopyahin ang one-time code na ito. Magagamit mo ito para i-reset ang PIN kapag nakalimutan mo, kahit offline.';

  @override
  String get pinRecoveryCopied => 'Nakopya ang recovery code.';

  @override
  String get pinCopy => 'Kopyahin';

  @override
  String get pinDone => 'Tapos';

  @override
  String get pinEnterFourDigits => 'Ilagay ang 4-digit na PIN.';

  @override
  String get pinIncorrect => 'Mali ang PIN. Subukan ulit.';

  @override
  String get pinInvalidRecoveryCode => 'Mali ang recovery code.';

  @override
  String get pinBiometricFailed =>
      'Hindi gumana o kinansela ang fingerprint/screen lock.';

  @override
  String get pinGoogleMismatch => 'Hindi tugma ang Google account.';

  @override
  String get pinResetTitle => 'I-reset ang Store PIN';

  @override
  String get pinUseBiometric => 'Gamitin ang Fingerprint / Screen Lock';

  @override
  String get pinForgot => 'Nakalimutan ang PIN?';

  @override
  String get pinRecoveryCodeLabel => 'Recovery code (hal. T360-XXXX)';

  @override
  String get pinVerifyGoogle => 'I-verify gamit ang Google Account';

  @override
  String get pinBackToPin => 'Bumalik sa PIN';

  @override
  String get pinResetButton => 'I-reset ang PIN';

  @override
  String get pinUnlock => 'I-unlock';

  @override
  String get pinDamaged =>
      'Sira ang PIN data. Mag-unlock gamit ang fingerprint, screen lock o Google, tapos gumawa ng bagong PIN.';

  @override
  String get pinRemoveDamaged => 'Tanggalin ang sirang PIN';

  @override
  String get pinMustBeFourDigits => 'Dapat eksaktong 4 na numero ang PIN.';

  @override
  String get pinMismatch => 'Hindi magkapareho ang mga PIN.';

  @override
  String get pinNewLabel => 'Bagong 4-digit na PIN';

  @override
  String get pinConfirmLabel => 'Ulitin ang 4-digit na PIN';

  @override
  String get ledgerHistoryTitle => 'Listahan ng Utang';

  @override
  String get ledgerReminderCopied => 'Nakopya ang paalala';

  @override
  String get receiptPrintDialogFailed => 'Hindi mabuksan ang print dialog.';

  @override
  String get ulatExpenseInvalid =>
      'Ilagay ang tamang pangalan at halaga ng gastos.';

  @override
  String get commonUndo => 'Ibalik';

  @override
  String get settingsSwitchStoreFailed =>
      'Hindi malipat ang store. Subukan ulit.';

  @override
  String get settingsDeleteStoreFailed =>
      'Hindi matanggal ang store. Subukan ulit.';

  @override
  String posRemovedFromCart(String name) {
    return 'Tinanggal ang $name';
  }

  @override
  String get receiptTotal => 'KABUUAN';

  @override
  String get receiptPayment => 'Paraan ng bayad';

  @override
  String get receiptPaid => 'Bayad';

  @override
  String get receiptChange => 'Sukli';

  @override
  String get receiptUtang => 'Utang';

  @override
  String get receiptThankYou => 'Salamat po!';

  @override
  String get receiptNoItems => '(Walang item)';

  @override
  String inventoryImportSkippedRows(String rows) {
    return 'Tingnan ang rows: $rows (walang pangalan o presyo, maling numero, hindi kilalang unit, o dobleng barcode).';
  }
}
