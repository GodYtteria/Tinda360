import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/customers/customer_draft.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_draft.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';
import 'package:tinda360/core/sales/sale_record.dart';
import 'package:tinda360/core/sales/sale_return_line.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/data/db/id_generator.dart';
import 'package:tinda360/data/repositories/expense_repository.dart';
import 'package:tinda360/features/pos/data/cart_storage.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/google_drive_backup_service.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/theme/adaptive_layout.dart';
import 'package:tinda360/theme/app_theme.dart';

import 'sequential_ids.dart';
import 'test_repositories.dart';

const String longProductName =
    'Tindahan ni Aling Nena Special Pancit Canton Chilimansi Flavor 60g';

const String longStoreName = 'Interes Test Tindahan ni Aling Nena';

const String longSukiName =
    'Maria Concepcion Dela Cruz-Villanueva ng Purok Sampaguita Barangay Uno';

final class LayoutScenario {
  const LayoutScenario({
    required this.width,
    required this.height,
    required this.pixelRatio,
    required this.textScale,
    required this.darkMode,
    required this.localeCode,
  });

  final double width;
  final double height;
  final double pixelRatio;
  final double textScale;
  final bool darkMode;
  final String localeCode;

  @override
  String toString() =>
      '${width.toInt()}x${height.toInt()} dpr=$pixelRatio '
      'scale=$textScale ${darkMode ? 'dark' : 'light'} $localeCode';
}

final class _IdleDriveBackupService implements DriveBackupService {
  @override
  Future<BackupAuthResult> signIn() async =>
      const BackupAuthSuccess(email: 'tindahan@gmail.com');

  @override
  Future<void> signOut() async {}

  @override
  Future<BackupSyncResult> uploadDatabase(
    File databaseFile, {
    required String storeId,
    required String? accountEmail,
    bool allowPrompt = false,
  }) async => const BackupSyncSuccess();

  @override
  Future<BackupSyncResult> downloadDatabaseTo(
    File destinationFile, {
    required String storeId,
    required String? accountEmail,
    bool allowPrompt = false,
  }) async => const BackupSyncSuccess();
}

final class SeededStore {
  SeededStore(this.repos);

  final TestRepositories repos;

  late final List<StockedProduct> products;
  late final List<CustomerBalance> balances;
  late final SaleRecord returnableSale;
  late final StockedProduct kiloProduct;
  late final StockedProduct longNameProduct;
  late final StockedProduct expiringProduct;

  Future<void> close() => repos.close();
}

String _unwrapId<FailureType extends Failure>(
  Result<String, FailureType> result,
) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('Seeding failed: $failure'),
};

void _requireOk<ValueType, FailureType extends Failure>(
  Result<ValueType, FailureType> result,
) {
  if (result is Err<ValueType, FailureType>) {
    throw StateError('Seeding failed: ${result.failure}');
  }
}

Future<SeededStore> seedStore() async {
  final repos = TestRepositories();
  final store = SeededStore(repos);
  final today = LocalDay.fromLocal(repos.clock.now());
  Money pesos(int amount) => Money(amount * 100, Currency.php);

  Future<String> addProduct({
    required String name,
    required ProductUnit unit,
    required int price,
    required int cost,
    Quantity initialStock = Quantity.zero,
    Quantity? lowStockAt,
    bool tracksStock = true,
    LocalDay? expiryDay,
    Money? utangPrice,
    String? barcode,
  }) async => _unwrapId(
    await repos.products.create(
      ProductDraft(
        name: name,
        unit: unit,
        price: pesos(price),
        cost: pesos(cost),
        initialStock: initialStock,
        lowStockAt: lowStockAt,
        tracksStock: tracksStock,
        expiryDay: expiryDay,
        utangPrice: utangPrice,
        barcode: barcode,
      ),
    ),
  );

  final longProductId = await addProduct(
    name: longProductName,
    unit: ProductUnit.pack,
    price: 14,
    cost: 11,
    initialStock: const Quantity.whole(48),
    lowStockAt: const Quantity.whole(10),
    utangPrice: pesos(16),
    barcode: '4800016644801',
  );
  final riceId = await addProduct(
    name: 'Bigas Premium',
    unit: ProductUnit.kilo,
    price: 58,
    cost: 50,
    initialStock: const Quantity.milli(25500),
    lowStockAt: const Quantity.whole(5),
  );
  final lowId = await addProduct(
    name: 'Kape 3-in-1',
    unit: ProductUnit.sachet,
    price: 9,
    cost: 7,
    initialStock: const Quantity.whole(3),
    lowStockAt: const Quantity.whole(10),
  );
  await addProduct(
    name: 'Sinigang Mix',
    unit: ProductUnit.sachet,
    price: 12,
    cost: 9,
  );
  final expiringId = await addProduct(
    name: 'Gatas ng Baka Fresh Milk 1L',
    unit: ProductUnit.liter,
    price: 95,
    cost: 80,
    initialStock: const Quantity.whole(12),
    expiryDay: today.plusDays(3),
  );
  await addProduct(
    name: 'Tinapay Pandesal Expired',
    unit: ProductUnit.bag,
    price: 30,
    cost: 22,
    initialStock: const Quantity.whole(6),
    expiryDay: today.plusDays(-2),
  );
  await addProduct(
    name: 'Load Credit Globe',
    unit: ProductUnit.piece,
    price: 10,
    cost: 9,
    tracksStock: false,
  );
  await addProduct(
    name: 'Sprite 1.5L',
    unit: ProductUnit.bottle,
    price: 75,
    cost: 62,
    initialStock: const Quantity.whole(20),
  );

  _requireOk(await repos.store.completeOnboarding(longStoreName));

  final sukiLongId = _unwrapId(
    await repos.customers.create(
      CustomerDraft(
        name: longSukiName,
        phone: '09171234567',
        creditLimit: pesos(500),
        interestPercentTenths: 50,
      ),
    ),
  );
  final sukiShortId = _unwrapId(
    await repos.customers.create(const CustomerDraft(name: 'Ate Lita')),
  );

  final cashSale = _unwrapId(
    await repos.sales.record(
      SaleDraft(
        method: PaymentMethod.cash,
        cashTendered: pesos(1000),
        lines: [
          SaleLineDraft(
            productId: longProductId,
            quantity: const Quantity.whole(3),
          ),
          SaleLineDraft(
            productId: riceId,
            quantity: const Quantity.milli(2500),
          ),
          SaleLineDraft(
            productId: lowId,
            quantity: const Quantity.whole(1),
          ),
        ],
      ),
    ),
  );
  _unwrapId(
    await repos.sales.record(
      SaleDraft(
        method: PaymentMethod.utang,
        customerId: sukiLongId,
        paidNow: pesos(20),
        lines: [
          SaleLineDraft(
            productId: expiringId,
            quantity: const Quantity.whole(2),
          ),
        ],
      ),
    ),
  );
  _unwrapId(
    await repos.sales.record(
      SaleDraft(
        method: PaymentMethod.utang,
        customerId: sukiShortId,
        lines: [
          SaleLineDraft(
            productId: riceId,
            quantity: const Quantity.whole(2),
          ),
        ],
      ),
    ),
  );
  _requireOk(await repos.customers.recordPayment(sukiShortId, pesos(30)));
  _requireOk(
    await repos.saleReturns.returnItems(cashSale, [
      SaleReturnLine(productId: lowId, quantity: const Quantity.whole(1)),
    ]),
  );

  final expenses = ExpenseRepository(
    db: repos.db,
    clock: repos.clock,
    ids: _ExpenseIds(SequentialIds()),
    log: repos.log,
    currency: Currency.php,
  );
  _requireOk(
    await expenses.addExpense(
      title: 'Kuryente at tubig para sa tindahan ngayong buwan',
      amount: pesos(850),
    ),
  );
  _requireOk(
    await expenses.addExpense(title: 'Yelo', amount: pesos(40)),
  );

  store.products = await repos.products.watchActive().first;
  store.balances = await repos.customers.watchBalances().first;
  final recentSales = await repos.sales
      .watchRecentSales(DayRange.single(today))
      .first;
  store.returnableSale = recentSales.firstWhere(
    (sale) => sale.lines.length > 1,
  );
  StockedProduct byName(String name) =>
      store.products.firstWhere((stocked) => stocked.product.name == name);
  store.kiloProduct = byName('Bigas Premium');
  store.longNameProduct = byName(longProductName);
  store.expiringProduct = byName('Gatas ng Baka Fresh Milk 1L');
  return store;
}

final class _ExpenseIds implements IdGenerator {
  _ExpenseIds(this._inner);

  final SequentialIds _inner;

  @override
  String next() => 'expense-${_inner.next()}';
}

Widget buildLayoutApp(
  TestRepositories repos,
  LayoutScenario scenario,
  Widget home, {
  required bool applyAppTextScaleLimit,
}) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWithValue(repos.db),
    clockProvider.overrideWithValue(repos.clock),
    appLogProvider.overrideWithValue(repos.log),
    activeCartStoreIdProvider.overrideWithValue(null),
    driveBackupServiceProvider.overrideWithValue(_IdleDriveBackupService()),
    databaseFileProvider.overrideWithValue(
      () async => File('/tmp/tinda360_layout_backup.sqlite'),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: scenario.darkMode ? ThemeMode.dark : ThemeMode.light,
    locale: Locale(scenario.localeCode),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, innerChild) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scenario.textScale)),
      child: applyAppTextScaleLimit
          ? AdaptiveTextScale(child: innerChild!)
          : innerChild!,
    ),
    home: home,
  ),
);

void applyScenarioView(WidgetTester tester, LayoutScenario scenario) {
  tester.view.devicePixelRatio = scenario.pixelRatio;
  tester.view.physicalSize = Size(
    scenario.width * scenario.pixelRatio,
    scenario.height * scenario.pixelRatio,
  );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> letStreamsSettle(WidgetTester tester) async {
  for (var round = 0; round < 3; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 400));
}

final Map<String, String> _layoutFindings = <String, String>{};

String _currentLayoutContext = 'setup';

final RegExp _sourceLocationPattern = RegExp(
  r'lib/(?:features|shared)/[\w/]+\.dart:\d+:\d+',
);

final RegExp _digitsPattern = RegExp(r'\d+(?:\.\d+)?');

void markLayoutContext(String context) {
  _currentLayoutContext = context;
}

void recordLayoutFinding(String description) {
  _layoutFindings.putIfAbsent(description, () => _currentLayoutContext);
}

void _recordLayoutError(FlutterErrorDetails details) {
  final firstLine = details
      .exceptionAsString()
      .split('\n')
      .first
      .replaceAll(_digitsPattern, 'N');
  final deepText = details.toString();
  final location =
      _sourceLocationPattern.firstMatch(deepText)?.group(0) ?? 'unknown';
  _layoutFindings.putIfAbsent(
    '$firstLine at $location',
    () => _currentLayoutContext,
  );
}

void Function(FlutterErrorDetails)? _previousErrorHandler;

void installLayoutErrorCollector() {
  _previousErrorHandler = FlutterError.onError;
  FlutterError.onError = _recordLayoutError;
}

void removeLayoutErrorCollector() {
  FlutterError.onError = _previousErrorHandler;
}

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

final Directory _supportDirectory = Directory.systemTemp.createTempSync(
  'tinda360_layout_',
);

void layoutTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      _pathProviderChannel,
      (call) async => _supportDirectory.path,
    );
    installLayoutErrorCollector();
    try {
      await body(tester);
    } finally {
      removeLayoutErrorCollector();
      messenger.setMockMethodCallHandler(_pathProviderChannel, null);
    }
    failOnLayoutFindings();
  });
}

void expectCleanLayout(WidgetTester tester, String context) {
  for (final element in find.byType(FilledButton).evaluate()) {
    final size = element.size;
    if (size == null) continue;
    if (size.width <= 0) {
      _layoutFindings.putIfAbsent(
        'zero-width primary button',
        () => context,
      );
    }
  }
}

void failOnLayoutFindings() {
  if (_layoutFindings.isEmpty) return;
  final summary = _layoutFindings.entries
      .map((entry) => '${entry.key}\n    first seen: ${entry.value}')
      .join('\n');
  _layoutFindings.clear();
  fail('Layout problems:\n$summary');
}

Future<void> scrollThroughAll(WidgetTester tester, String context) async {
  markLayoutContext('$context (scrolling)');
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  final target = scrollables.first;
  for (var step = 0; step < 14; step++) {
    await tester.drag(target, const Offset(0, -320), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 120));
    expectCleanLayout(tester, '$context scroll step $step');
  }
}

typedef SheetOpener = Future<void> Function(BuildContext context);

final class SheetLauncher extends StatefulWidget {
  const SheetLauncher({required this.open, super.key});

  final SheetOpener open;

  @override
  State<SheetLauncher> createState() => _SheetLauncherState();
}

class _SheetLauncherState extends State<SheetLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.open(context));
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('launcher')));
}

Future<void> disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
}
