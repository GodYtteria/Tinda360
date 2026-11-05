import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/sales_summary.dart';
import 'package:tinda360/core/sales/sold_line.dart';

abstract final class SaleMath {
  static Money lineTotal(Money unitPrice, Quantity quantity) {
    const half = Quantity.milliPerUnit ~/ 2;
    final scaled = unitPrice.minorUnits * quantity.milli;
    return Money((scaled + half) ~/ Quantity.milliPerUnit, unitPrice.currency);
  }

  static const int _sequenceDigits = 3;

  static String receiptNumber({required int daySerial, required int dayOrder}) {
    final date = LocalDay(daySerial).toLocalDate();
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final order = dayOrder.toString().padLeft(_sequenceDigits, '0');
    return '$year$month$day-$order';
  }

  static Money changeDue({required Money total, required Money tendered}) =>
      tendered - total;

  static SalesSummary summarize(Iterable<SoldLine> lines, Currency currency) {
    var revenue = Money.zero(currency);
    var cost = Money.zero(currency);
    final saleIds = <String>{};
    for (final line in lines) {
      revenue += lineTotal(line.unitPrice, line.quantity);
      cost += lineTotal(line.unitCost, line.quantity);
      saleIds.add(line.saleId);
    }
    return SalesSummary(
      revenue: revenue,
      cost: cost,
      saleCount: saleIds.length,
    );
  }
}
