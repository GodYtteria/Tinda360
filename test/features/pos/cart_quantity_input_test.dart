import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/inventory/presentation/product_form_logic.dart';
import 'package:tinda360/features/pos/presentation/cart_quantity_dialog.dart';
import 'package:tinda360/l10n/app_localizations.dart';

StockedProduct _stockedProduct({
  required ProductUnit unit,
  required Quantity stock,
}) => StockedProduct(
  product: Product(
    id: 'product-1',
    name: 'Bigas Dinorado',
    unit: unit,
    price: const Money(5000, Currency.php),
    cost: const Money(4200, Currency.php),
  ),
  stock: stock,
);

void main() {
  amountTests();
  final english = lookupAppLocalizations(const Locale('en'));
  final kiloRice = _stockedProduct(
    unit: ProductUnit.kilo,
    stock: const Quantity.milli(2500),
  );
  final pieceCoffee = _stockedProduct(
    unit: ProductUnit.piece,
    stock: const Quantity.whole(30),
  );

  ({Quantity? quantity, String? errorMessage}) check(
    String typedText,
    StockedProduct stocked,
  ) => validateCartQuantityInput(
    typedText,
    stocked: stocked,
    localizations: english,
  );

  test('accepts a big whole number within stock', () {
    final result = check('24', pieceCoffee);
    expect(result.quantity, const Quantity.whole(24));
    expect(result.errorMessage, isNull);
  });

  test('accepts the exact stock and a quarter kilo', () {
    expect(check('2.5', kiloRice).quantity, const Quantity.milli(2500));
    expect(check('0.25', kiloRice).quantity, const Quantity.milli(250));
    expect(check(' .5 ', kiloRice).quantity, isNull);
  });

  test('refuses more than the stock with the out-of-stock message', () {
    final result = check('31', pieceCoffee);
    expect(result.quantity, isNull);
    expect(result.errorMessage, 'No more stock for Bigas Dinorado.');
    expect(check('2.501', kiloRice).quantity, isNull);
  });

  test('refuses decimals for whole-only units and junk input', () {
    for (final typedText in ['2.5', '', '   ', 'abc', '-3', '1e3', '٣']) {
      final result = check(typedText, pieceCoffee);
      expect(result.quantity, isNull, reason: typedText);
      expect(result.errorMessage, 'Enter a valid quantity.', reason: typedText);
    }
    expect(check('1.2345', kiloRice).quantity, isNull);
  });

  test('zero is accepted so the line can be removed', () {
    expect(check('0', pieceCoffee).quantity, Quantity.zero);
  });

  test('decimal text round-trips through the parser', () {
    for (final milli in [0, 250, 1000, 1500, 2005, 999999]) {
      final quantity = Quantity.milli(milli);
      final text = ProductFormLogic.decimalText(quantity);
      expect(
        ProductFormLogic.parseQuantity(text, allowsFraction: true),
        quantity,
        reason: text,
      );
    }
    expect(ProductFormLogic.decimalText(const Quantity.milli(250)), '0.25');
    expect(ProductFormLogic.decimalText(const Quantity.whole(24)), '24');
  });
}

void amountTests() {
  const price = Money(5000, Currency.php);
  const stock = Quantity.whole(10);

  group('quantityForAmount', () {
    test('divides amount by price', () {
      expect(
        quantityForAmount('20', unitPrice: price, stock: stock),
        const Quantity.milli(400),
      );
    });

    test('rounds down to the milli unit', () {
      expect(
        quantityForAmount(
          '10',
          unitPrice: const Money(3000, Currency.php),
          stock: stock,
        ),
        const Quantity.milli(333),
      );
    });

    test('caps at stock', () {
      expect(
        quantityForAmount(
          '9999',
          unitPrice: price,
          stock: const Quantity.milli(2500),
        ),
        const Quantity.milli(2500),
      );
    });

    test('accepts centavos', () {
      expect(
        quantityForAmount('12.50', unitPrice: price, stock: stock),
        const Quantity.milli(250),
      );
      expect(
        quantityForAmount('12.5', unitPrice: price, stock: stock),
        const Quantity.milli(250),
      );
    });

    test('zero price disables amount mode', () {
      expect(
        quantityForAmount(
          '20',
          unitPrice: const Money(0, Currency.php),
          stock: stock,
        ),
        isNull,
      );
    });

    test('rejects blank, invalid, unicode, zero and tiny amounts', () {
      for (final bad in [
        '',
        '  ',
        'abc',
        '1.234',
        '-5',
        '٢٠',
        '１０',
        '0',
        '0.00',
        '0.01',
        '1e3',
        '.',
      ]) {
        expect(
          quantityForAmount(bad, unitPrice: price, stock: stock),
          isNull,
          reason: bad,
        );
      }
    });

    test('rejects when stock is zero', () {
      expect(
        quantityForAmount('20', unitPrice: price, stock: Quantity.zero),
        isNull,
      );
    });
  });
}
