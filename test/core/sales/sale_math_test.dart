import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/sale_math.dart';
import 'package:tinda360/core/sales/sold_line.dart';

void main() {
  group('SaleMath.lineTotal', () {
    test('whole units multiply exactly', () {
      expect(
        SaleMath.lineTotal(
          const Money(1500, Currency.php),
          const Quantity.whole(3),
        ),
        const Money(4500, Currency.php),
      );
    });

    test('a quarter kilo of ₱45.00 rice is ₱11.25', () {
      expect(
        SaleMath.lineTotal(
          const Money(4500, Currency.php),
          const Quantity.milli(250),
        ),
        const Money(1125, Currency.php),
      );
    });

    test('rounds half-up once to the nearest centavo', () {
      expect(
        SaleMath.lineTotal(
          const Money(999, Currency.php),
          const Quantity.milli(333),
        ),
        const Money(333, Currency.php),
      );
      expect(
        SaleMath.lineTotal(
          const Money(100, Currency.php),
          const Quantity.milli(5),
        ),
        const Money(1, Currency.php),
      );
    });
  });

  test('changeDue is tendered minus total', () {
    expect(
      SaleMath.changeDue(
        total: const Money(4500, Currency.php),
        tendered: const Money(10000, Currency.php),
      ),
      const Money(5500, Currency.php),
    );
  });

  test('summarize counts distinct sales and derives profit', () {
    const lines = [
      SoldLine(
        saleId: 'a',
        quantity: Quantity.whole(2),
        unitPrice: Money(1500, Currency.php),
        unitCost: Money(1200, Currency.php),
      ),
      SoldLine(
        saleId: 'a',
        quantity: Quantity.whole(1),
        unitPrice: Money(800, Currency.php),
        unitCost: Money(600, Currency.php),
      ),
      SoldLine(
        saleId: 'b',
        quantity: Quantity.milli(500),
        unitPrice: Money(4500, Currency.php),
        unitCost: Money(4000, Currency.php),
      ),
    ];
    final summary = SaleMath.summarize(lines, Currency.php);
    expect(summary.saleCount, 2);
    expect(summary.revenue, const Money(6050, Currency.php));
    expect(summary.cost, const Money(5000, Currency.php));
    expect(summary.profit, const Money(1050, Currency.php));
  });
}
