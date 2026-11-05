import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/features/inventory/presentation/product_sheet.dart';
import 'package:tinda360/features/inventory/presentation/stock_history_sheet.dart';
import 'package:tinda360/features/pos/presentation/bantay_chip.dart';
import 'package:tinda360/features/pos/presentation/cart_quantity_dialog.dart';
import 'package:tinda360/features/pos/presentation/checkout_price_dialog.dart';
import 'package:tinda360/features/pos/presentation/checkout_sheet.dart';
import 'package:tinda360/features/pos/presentation/pos_cart_notifier.dart';
import 'package:tinda360/features/pos/presentation/receipt_preview_sheet.dart';
import 'package:tinda360/features/pos/presentation/sale_done_sheet.dart';
import 'package:tinda360/features/settings/presentation/settings_screen.dart';
import 'package:tinda360/features/shell/main_shell.dart';
import 'package:tinda360/features/ulat/presentation/sale_return_sheet.dart';
import 'package:tinda360/features/utang/presentation/suki_ledger_sheet.dart';
import 'package:tinda360/features/utang/presentation/utang_pay_sheet.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/receipt_print_service.dart';
import 'package:tinda360/shared/widgets/csv_preview_sheet.dart';

import '../support/layout_harness.dart';

const List<Size> _allSizes = [
  Size(320, 568),
  Size(360, 640),
  Size(360, 800),
  Size(411, 891),
  Size(412, 915),
  Size(600, 960),
];

const List<double> _pixelRatios = [1.5, 2.625, 3.5];

const List<double> _textScales = [1.0, 1.3, 1.6, 2.0];

const List<LayoutScenario> _reducedScenarios = [
  LayoutScenario(
    width: 320,
    height: 568,
    pixelRatio: 2.625,
    textScale: 1.6,
    darkMode: false,
    localeCode: 'en',
  ),
  LayoutScenario(
    width: 320,
    height: 568,
    pixelRatio: 3.5,
    textScale: 2.0,
    darkMode: true,
    localeCode: 'fil',
  ),
  LayoutScenario(
    width: 360,
    height: 800,
    pixelRatio: 1.5,
    textScale: 1.0,
    darkMode: false,
    localeCode: 'fil',
  ),
  LayoutScenario(
    width: 600,
    height: 960,
    pixelRatio: 2.625,
    textScale: 1.0,
    darkMode: true,
    localeCode: 'en',
  ),
];

List<LayoutScenario> _fullScenarios() {
  final scenarios = <LayoutScenario>[];
  var index = 0;
  for (final size in _allSizes) {
    for (final textScale in _textScales) {
      for (final pixelRatio in _pixelRatios) {
        scenarios.add(
          LayoutScenario(
            width: size.width,
            height: size.height,
            pixelRatio: pixelRatio,
            textScale: textScale,
            darkMode: index.isOdd,
            localeCode: (index ~/ 2).isOdd ? 'fil' : 'en',
          ),
        );
        index++;
      }
    }
  }
  return scenarios;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  SeededStore store,
  LayoutScenario scenario,
  Widget screen,
  String label, {
  required bool limitTextScaleLikeApp,
}) async {
  markLayoutContext('$label @ $scenario');
  applyScenarioView(tester, scenario);
  await tester.pumpWidget(
    buildLayoutApp(
      store.repos,
      scenario,
      screen,
      applyAppTextScaleLimit: limitTextScaleLikeApp,
    ),
  );
  await letStreamsSettle(tester);
}

Future<void> _runSheet(
  WidgetTester tester,
  SeededStore store,
  LayoutScenario scenario,
  String name,
  SheetOpener open, {
  Future<void> Function()? interact,
}) async {
  final context = '$name @ $scenario';
  await _pumpScreen(
    tester,
    store,
    scenario,
    SheetLauncher(open: open),
    name,
    limitTextScaleLikeApp: false,
  );
  expectCleanLayout(tester, '$context open');
  if (interact != null) {
    await interact();
    await letStreamsSettle(tester);
    expectCleanLayout(tester, '$context interact');
  }
  await scrollThroughAll(tester, context);
  await disposeApp(tester);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final target = find.text(text, skipOffstage: false);
  if (target.evaluate().isEmpty) {
    recordLayoutFinding(
      'expected text not found: $text among '
      '${tester.widgetList<Text>(find.byType(Text, skipOffstage: false)).map((widget) => widget.data).whereType<String>().join(' | ')}',
    );
    return;
  }
  await tester.ensureVisible(target.first);
  await tester.tap(target.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late SeededStore store;
  final stopwatch = Stopwatch();

  setUpAll(() async {
    stopwatch.start();
    TestWidgetsFlutterBinding.ensureInitialized();
    store = await seedStore();
  });

  tearDownAll(() async {
    await store.close();
    stopwatch.stop();
    debugPrint('layout test elapsed: ${stopwatch.elapsed}');
  });

  group('full matrix screens', () {
    final tabNames = ['pos', 'inventory', 'utang', 'reports'];
    for (var tabIndex = 0; tabIndex < tabNames.length; tabIndex++) {
      layoutTest('MainShell tab ${tabNames[tabIndex]}', (tester) async {
        for (final scenario in _fullScenarios()) {
          final context = 'tab ${tabNames[tabIndex]} @ $scenario';
          await _pumpScreen(
            tester,
            store,
            scenario,
            MainShell(onOpenSettings: () {}, initialIndex: tabIndex),
            'tab ${tabNames[tabIndex]}',
            limitTextScaleLikeApp: true,
          );
          if (tabIndex == 0) {
            final container = ProviderScope.containerOf(
              tester.element(find.byType(MaterialApp)),
            );
            final notifier = container.read(posCartProvider.notifier);
            for (final stocked in store.products.take(4)) {
              notifier.increment(
                stocked.product.id,
                available: stocked.sellCap,
              );
            }
            await tester.pump(const Duration(milliseconds: 200));
          }
          expectCleanLayout(tester, context);
          await scrollThroughAll(tester, context);
          await disposeApp(tester);
        }
      });
    }

    layoutTest('SettingsScreen', (tester) async {
      for (final scenario in _fullScenarios()) {
        final context = 'settings @ $scenario';
        await _pumpScreen(
          tester,
          store,
          scenario,
          const SettingsScreen(),
          'settings',
          limitTextScaleLikeApp: true,
        );
        expectCleanLayout(tester, context);
        await scrollThroughAll(tester, context);
        await disposeApp(tester);
      }
    });
  });

  group('readability on a tight phone', () {
    const tightScenario = LayoutScenario(
      width: 360,
      height: 640,
      pixelRatio: 2.625,
      textScale: 1.3,
      darkMode: false,
      localeCode: 'en',
    );
    const minimumNameWidthFraction = 0.55;
    const minimumStoreNameWidthFraction = 0.45;

    layoutTest('POS header puts the Bantay chip below the store name', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        store,
        tightScenario,
        MainShell(onOpenSettings: () {}),
        'pos header',
        limitTextScaleLikeApp: true,
      );
      final storeNameFinder = find.text(longStoreName);
      expect(storeNameFinder, findsOneWidget);
      final nameRect = tester.getRect(storeNameFinder);
      expect(
        nameRect.width / tightScenario.width,
        greaterThanOrEqualTo(minimumStoreNameWidthFraction),
      );
      final chipRect = tester.getRect(find.byType(BantayChip));
      expect(chipRect.top, greaterThanOrEqualTo(nameRect.bottom - 1));
      await disposeApp(tester);
    });

    layoutTest('POS and inventory rows keep the product name wide', (
      tester,
    ) async {
      for (final tabIndex in [0, 1]) {
        await _pumpScreen(
          tester,
          store,
          tightScenario,
          MainShell(onOpenSettings: () {}, initialIndex: tabIndex),
          'row width tab $tabIndex',
          limitTextScaleLikeApp: true,
        );
        final nameFinder = find.text(longProductName);
        expect(nameFinder, findsWidgets);
        expect(
          tester.getSize(nameFinder.first).width / tightScenario.width,
          greaterThanOrEqualTo(minimumNameWidthFraction),
          reason: 'tab $tabIndex product name too narrow',
        );
        await disposeApp(tester);
      }
    });
  });

  group('reduced matrix sheets and dialogs', () {
    Future<void> openCheckout(BuildContext context) {
      final container = ProviderScope.containerOf(context);
      container.listen(posCartProvider, (previous, next) {});
      final cartNotifier = container.read(posCartProvider.notifier);
      final cart = {
        store.longNameProduct.product.id: const Quantity.whole(3),
        store.kiloProduct.product.id: const Quantity.milli(2500),
        store.expiringProduct.product.id: const Quantity.whole(1),
      };
      for (final entry in cart.entries) {
        final stocked = store.products.firstWhere(
          (candidate) => candidate.product.id == entry.key,
        );
        cartNotifier.setQuantity(
          entry.key,
          entry.value,
          available: stocked.sellCap,
        );
      }
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => CheckoutSheet(products: store.products, cart: cart),
      );
    }

    final sheetCases =
        <
          String,
          ({SheetOpener open, Future<void> Function(WidgetTester)? interact})
        >{
          'checkout cash': (open: openCheckout, interact: null),
          'checkout cash shortfall with suki': (
            open: openCheckout,
            interact: (tester) async {
              await tester.enterText(find.byType(TextField).first, '1');
              await tester.pump(const Duration(milliseconds: 300));
              await letStreamsSettle(tester);
              await _tapText(tester, longSukiName);
            },
          ),
          'checkout utang with interest': (
            open: openCheckout,
            interact: (tester) async {
              await _tapText(tester, 'Utang');
              await letStreamsSettle(tester);
              await _tapText(tester, longSukiName);
              await letStreamsSettle(tester);
            },
          ),
          'checkout e-wallet': (
            open: openCheckout,
            interact: (tester) async {
              await _tapText(tester, 'E-wallet');
            },
          ),
          'price dialog': (
            open: (context) => showLinePriceDialog(
              context,
              productName: longProductName,
              normalPrice: Money(1400, Currency.php),
              currentOverride: Money(1200, Currency.php),
            ),
            interact: null,
          ),
          'quantity dialog amount mode': (
            open: (context) => showCartQuantityDialog(
              context,
              stocked: store.kiloProduct,
              currentQuantity: const Quantity.milli(2500),
            ),
            interact: (tester) async {
              final dialogContext = tester.element(find.byType(AlertDialog));
              await _tapText(
                tester,
                AppLocalizations.of(dialogContext).posAmountMode,
              );
              await tester.enterText(find.byType(TextField).first, '100');
              await tester.pump(const Duration(milliseconds: 300));
            },
          ),
          'product sheet create': (
            open: (context) => ProductSheet.show(context),
            interact: null,
          ),
          'product sheet edit expiring': (
            open: (context) =>
                ProductSheet.show(context, existing: store.expiringProduct),
            interact: null,
          ),
          'product sheet edit long name': (
            open: (context) =>
                ProductSheet.show(context, existing: store.longNameProduct),
            interact: (tester) async {
              for (final element in find.byType(Switch).evaluate().toList()) {
                await tester.ensureVisible(find.byWidget(element.widget));
                await tester.tap(
                  find.byWidget(element.widget),
                  warnIfMissed: false,
                );
                await tester.pump(const Duration(milliseconds: 300));
              }
            },
          ),
          'suki ledger sheet': (
            open: (context) => SukiLedgerSheet.show(
              context,
              balance: store.balances.firstWhere(
                (balance) => balance.customer.name == longSukiName,
              ),
              onPay: () {},
            ),
            interact: null,
          ),
          'pay sheet': (
            open: (context) => UtangPaySheet.showPay(
              context,
              store.balances.firstWhere(
                (balance) => balance.customer.name == longSukiName,
              ),
            ),
            interact: null,
          ),
          'new suki sheet': (
            open: (context) => UtangPaySheet.showNewSuki(context),
            interact: null,
          ),
          'return sheet': (
            open: (context) =>
                showSaleReturnSheet(context, sale: store.returnableSale),
            interact: null,
          ),
          'receipt preview': (
            open: (context) => ReceiptPreviewSheet.show(
              context,
              storeName: 'Tindahan ni Aling Nena at Mga Anak Sari-Sari Store',
              lines: [
                '3 x $longProductName = P42.00',
                '2.5 kilo Bigas Premium = P145.00',
              ],
              total: Money(18700, Currency.php),
              paid: Money(20000, Currency.php),
              change: Money(1300, Currency.php),
              paymentLabel: 'Cash',
              timestamp: DateTime(2026, 11, 17, 10),
              details: const ReceiptDetails(
                receiptNumber: 'OR-000123',
                customerName: longSukiName,
                cashierName: 'Cashier with a very long name Juan Dela Cruz',
              ),
            ),
            interact: null,
          ),
          'sale done sheet': (
            open: (context) => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => SaleDoneSheet(
                total: Money(18700, Currency.php),
                paid: Money(20000, Currency.php),
                change: Money(1300, Currency.php),
                receiptLines: ['3 x $longProductName = P42.00'],
                paymentMethod: PaymentMethod.cash,
                storeName: 'Tindahan ni Aling Nena at Mga Anak Sari-Sari Store',
                timestamp: DateTime(2026, 11, 17, 10),
              ),
            ),
            interact: null,
          ),
          'stock history': (
            open: (context) =>
                StockHistorySheet.show(context, store.longNameProduct.product),
            interact: null,
          ),
          'csv preview': (
            open: (context) => CsvPreviewSheet.show(
              context,
              title: 'Utang export for all suki customers this month',
              headers: [
                'Suki name',
                'Phone number',
                'Balance owed',
                'Credit limit',
                'Interest',
              ],
              rows: [
                for (var row = 0; row < 8; row++)
                  [longSukiName, '09171234567', '1,250.00', '5,000.00', '5.0%'],
              ],
              fileName: 'utang_export_2026_11_17.csv',
              csvContent: 'a,b\n1,2',
              successMessage: 'Saved',
            ),
            interact: null,
          ),
        };

    for (final entry in sheetCases.entries) {
      layoutTest(entry.key, (tester) async {
        final interact = entry.value.interact;
        for (final scenario in _reducedScenarios) {
          await _runSheet(
            tester,
            store,
            scenario,
            entry.key,
            entry.value.open,
            interact: interact == null ? null : () => interact(tester),
          );
        }
      });
    }
  });
}
