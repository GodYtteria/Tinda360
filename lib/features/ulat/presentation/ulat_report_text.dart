import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/sales_summary.dart';
import 'package:tinda360/core/sales/top_product.dart';
import 'package:tinda360/data/repositories/cash_count_repository.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/formatters.dart';

const int reportTextTopProductLimit = 3;

String buildUlatReportText({
  required AppLocalizations localizations,
  required String storeName,
  required String rangeLabel,
  required SalesSummary summary,
  required List<TopProduct> topProducts,
  required Money totalExpenses,
  required Money totalUtang,
  CashCountEntry? latestCashCount,
}) {
  final netIncome = summary.profit - totalExpenses;
  final lines = <String>[
    '$storeName · $rangeLabel',
    '${localizations.ulatShareRevenueLabel}: ${formatMoney(summary.revenue)}',
    '${localizations.ulatShareProfitLabel}: ${formatMoney(summary.profit)}',
    '${localizations.ulatShareTransactionsLabel}: ${summary.saleCount}',
    '${localizations.ulatShareExpensesLabel}: ${formatMoney(totalExpenses)}',
    '${localizations.ulatShareNetIncomeLabel}: ${formatMoney(netIncome)}',
    '${localizations.ulatShareUtangLabel}: ${formatMoney(totalUtang)}',
  ];
  if (topProducts.isNotEmpty) {
    lines.add('${localizations.ulatShareTopProductsLabel}:');
    final shown = topProducts.take(reportTextTopProductLimit).toList();
    for (var index = 0; index < shown.length; index++) {
      final product = shown[index];
      lines.add(
        '${index + 1}. ${product.productName} - '
        '${formatMoney(product.totalRevenue)}',
      );
    }
  }
  if (latestCashCount != null) {
    lines.add(
      localizations.ulatShareCashCountLine(
        formatMoney(latestCashCount.expected),
        formatMoney(latestCashCount.counted),
        _cashDifferenceText(localizations, latestCashCount.difference),
      ),
    );
  }
  return lines.join('\n');
}

String _cashDifferenceText(AppLocalizations localizations, Money difference) {
  if (difference.isPositive) {
    return localizations.cashCountOver(formatMoney(difference));
  }
  if (difference.isNegative) {
    return localizations.cashCountShort(
      formatMoney(Money(-difference.minorUnits, difference.currency)),
    );
  }
  return localizations.cashCountExact;
}
