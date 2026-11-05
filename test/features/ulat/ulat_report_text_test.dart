import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/sales_summary.dart';
import 'package:tinda360/core/sales/top_product.dart';
import 'package:tinda360/data/repositories/cash_count_repository.dart';
import 'package:tinda360/features/ulat/presentation/ulat_report_text.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/formatters.dart';

Money _php(int minor) => Money(minor, Currency.php);

TopProduct _top(String name, int revenueMinor) => TopProduct(
  productId: name,
  productName: name,
  unit: ProductUnit.piece,
  totalQuantity: const Quantity.milli(1000),
  totalRevenue: _php(revenueMinor),
);

final SalesSummary _summary = SalesSummary(
  revenue: _php(100000),
  cost: _php(70000),
  saleCount: 12,
);

String _build(
  String languageCode, {
  List<TopProduct> topProducts = const [],
  CashCountEntry? cashCount,
}) => buildUlatReportText(
  localizations: lookupAppLocalizations(Locale(languageCode)),
  storeName: 'Tindahan ni Aling Nena',
  rangeLabel: 'Today',
  summary: _summary,
  topProducts: topProducts,
  totalExpenses: _php(5000),
  totalUtang: _php(2500),
  latestCashCount: cashCount,
);

void main() {
  test('filipino report has labels, values and net income', () {
    final text = _build('fil');
    final lines = text.split('\n');
    expect(lines.first, 'Tindahan ni Aling Nena · Today');
    expect(text, contains('Benta: ${formatMoney(_php(100000))}'));
    expect(text, contains('Tubo: '));
    expect(text, contains('Mga transaksyon: 12'));
    expect(text, contains('Gastos: '));
    expect(text, contains('Netong kita: '));
    expect(text, contains('Natitirang utang: '));
    expect(text, isNot(contains('Top 3')));
    expect(text, isNot(contains('Bilang ng pera')));
  });

  test('net income is profit minus expenses', () {
    final text = _build('en');
    final profitLine = text
        .split('\n')
        .firstWhere(
          (line) => line.startsWith('Profit'),
        );
    final netLine = text
        .split('\n')
        .firstWhere(
          (line) => line.startsWith('Net income'),
        );
    expect(profitLine, contains('300'));
    expect(netLine, contains('250'));
  });

  test('top products limited to three', () {
    final text = _build(
      'en',
      topProducts: [
        _top('A', 400),
        _top('B', 300),
        _top('C', 200),
        _top('D', 100),
      ],
    );
    expect(text, contains('Top 3 products:'));
    expect(text, contains('3. C'));
    expect(text, isNot(contains('4. D')));
  });

  test('cash count line shows shortage', () {
    final text = _build(
      'en',
      cashCount: CashCountEntry(
        id: 'c1',
        createdAtMs: 1,
        day: const LocalDay(20000),
        expected: _php(10000),
        counted: _php(9000),
        note: null,
      ),
    );
    expect(text, contains('Cash count: Expected'));
    expect(text, contains('Short'));
  });

  test('cash count line shows exact and over', () {
    CashCountEntry entry(int counted) => CashCountEntry(
      id: 'c',
      createdAtMs: 1,
      day: const LocalDay(20000),
      expected: _php(10000),
      counted: _php(counted),
      note: null,
    );
    expect(_build('fil', cashCount: entry(10000)), contains('Bilang ng pera'));
    expect(_build('en', cashCount: entry(11000)), contains('Over'));
    expect(_build('en', cashCount: entry(10000)), contains('Exact'));
  });
}
