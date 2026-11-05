import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/sales/sale_math.dart';

void main() {
  test('receipt number is date plus zero padded daily order', () {
    final serial = LocalDay.fromLocal(DateTime(2026, 1, 5)).serial;
    expect(
      SaleMath.receiptNumber(daySerial: serial, dayOrder: 7),
      '20260105-007',
    );
    expect(
      SaleMath.receiptNumber(daySerial: serial, dayOrder: 1234),
      '20260105-1234',
    );
  });
}
