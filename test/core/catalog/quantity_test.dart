import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/quantity.dart';

void main() {
  test('whole units are stored in thousandths', () {
    expect(const Quantity.whole(3).milli, 3000);
    expect(const Quantity.whole(3).isWhole, isTrue);
    expect(const Quantity.milli(250).isWhole, isFalse);
  });

  test('arithmetic is exact', () {
    expect(
      const Quantity.milli(250) + const Quantity.milli(750),
      const Quantity.whole(1),
    );
    expect(-const Quantity.whole(2), const Quantity.milli(-2000));
  });
}
