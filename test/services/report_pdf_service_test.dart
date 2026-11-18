import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/sales_summary.dart';
import 'package:tinda360/core/sales/top_product.dart';
import 'package:tinda360/features/ulat/presentation/ulat_notifier.dart';
import 'package:tinda360/l10n/app_localizations_en.dart';
import 'package:tinda360/l10n/app_localizations_fil.dart';
import 'package:tinda360/services/report_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final localizations = AppLocalizationsEn();
  final today = LocalDay.fromLocal(DateTime(2026, 11, 17));

  test('PDF table and signature strings are localized for Filipino', () {
    final filipino = AppLocalizationsFil();
    expect(localizations.reportPdfMetricHeader, 'Metric');
    expect(
      localizations.reportPdfPreparedBy('Tindahan'),
      'Tindahan - Prepared by Store Owner',
    );
    expect(filipino.reportPdfMetricHeader, isNot('Metric'));
    expect(filipino.reportPdfProductHeader, isNot('Product'));
    expect(
      filipino.reportPdfPreparedBy('Tindahan'),
      isNot(contains('Prepared')),
    );
    expect(filipino.reportsProfitCard, 'Tubo');
  });

  test('buildReportPdf produces valid PDF bytes for empty UlatState', () async {
    final emptyState = UlatState(
      period: ReportPeriod.today,
      range: DayRange.single(today),
      summary: const SalesSummary(
        revenue: Money.zero(Currency.php),
        cost: Money.zero(Currency.php),
        saleCount: 0,
      ),
      totalUtang: const Money.zero(Currency.php),
      sukiWithUtangCount: 0,
      topProducts: const [],
    );

    final bytes = await ReportPdfService.buildReportPdf(
      storeName: '',
      periodLabel: localizations.reportsToday,
      state: emptyState,
      localizations: localizations,
      totalExpenses: const Money.zero(Currency.php),
      logoBytes: Uint8List(0),
    );

    expect(bytes, isNotEmpty);
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
  });

  test(
    'buildReportPdf produces valid PDF bytes for populated UlatState',
    () async {
      final populatedState = UlatState(
        period: ReportPeriod.week,
        range: DayRange(today.plusDays(-6), today),
        summary: const SalesSummary(
          revenue: Money(152500, Currency.php),
          cost: Money(110000, Currency.php),
          saleCount: 24,
        ),
        totalUtang: const Money(35000, Currency.php),
        sukiWithUtangCount: 3,
        topProducts: const [
          TopProduct(
            productId: 'prod-1',
            productName: 'Lucky Me Pancit Canton',
            unit: ProductUnit.pack,
            totalQuantity: Quantity.whole(18),
            totalRevenue: Money(32400, Currency.php),
          ),
          TopProduct(
            productId: 'prod-2',
            productName: 'Bigas Sinandomeng',
            unit: ProductUnit.kilo,
            totalQuantity: Quantity.milli(2500),
            totalRevenue: Money(15000, Currency.php),
          ),
        ],
      );

      final bytes = await ReportPdfService.buildReportPdf(
        storeName: 'Tindahan ni Aling Nena',
        periodLabel: localizations.reportsWeek,
        state: populatedState,
        localizations: localizations,
        totalExpenses: const Money(2500, Currency.php),
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    },
  );
}
