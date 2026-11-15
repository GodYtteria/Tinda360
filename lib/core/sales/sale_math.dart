import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/sales_summary.dart';
import 'package:tinda360/core/sales/sold_line.dart';

/// The one place sale amounts are computed. Pure and total.
abstract final class SaleMath {
  /// The amount for [quantity] at [unitPrice], rounded half-up once to the
  /// nearest minor unit. Both inputs are expected to be non-negative.
  static Money lineTotal(Money unitPrice, Quantity quantity) {
    const half = Quantity.milliPerUnit ~/ 2;
    final scaled = unitPrice.minorUnits * quantity.milli;
    return Money((scaled + half) ~/ Quantity.milliPerUnit, unitPrice.currency);
  }

  /// Change due when [tendered] is handed over for [total]. Negative means
  /// the payment is short.
  static Money changeDue({required Money total, required Money tendered}) =>
      tendered - total;

  /// Folds sold lines into totals. Each line is rounded once, by [lineTotal].
  static SalesSummary summarize(Iterable<SoldLine> lines, Currency currency) {
    var revenue = Money.zero(currency);
    var cost = Money.zero(currency);
    final saleIds = <String>{};
    for (final line in lines) {
      revenue += lineTotal(line.unitPrice, line.quantity);
      cost += lineTotal(line.unitCost, line.quantity);
      saleIds.add(line.saleId);
    }
    return SalesSummary(revenue: revenue, cost: cost, saleCount: saleIds.length);
  }
}
