import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/features/pos/presentation/checkout_utang_pricing.dart';

Money pesos(int amount) => Money(amount * 100, Currency.php);

StockedProduct stockedProduct(String id, int price, {int? utangPrice}) =>
    StockedProduct(
      product: Product(
        id: id,
        name: id,
        unit: ProductUnit.kilo,
        price: pesos(price),
        cost: pesos(price - 5),
        utangPrice: utangPrice == null ? null : pesos(utangPrice),
      ),
      stock: const Quantity.whole(50),
    );

void main() {
  group('effectiveUnitPrice', () {
    test('cash mode uses the normal price', () {
      expect(
        effectiveUnitPrice(
          normalPrice: pesos(50),
          utangPrice: pesos(55),
          manualOverride: null,
          useUtangPrices: false,
        ),
        pesos(50),
      );
    });

    test('utang mode uses the utang price', () {
      expect(
        effectiveUnitPrice(
          normalPrice: pesos(50),
          utangPrice: pesos(55),
          manualOverride: null,
          useUtangPrices: true,
        ),
        pesos(55),
      );
    });

    test('utang mode without an utang price keeps the normal price', () {
      expect(
        effectiveUnitPrice(
          normalPrice: pesos(50),
          utangPrice: null,
          manualOverride: null,
          useUtangPrices: true,
        ),
        pesos(50),
      );
    });

    test('a manual override beats the utang price', () {
      expect(
        effectiveUnitPrice(
          normalPrice: pesos(50),
          utangPrice: pesos(55),
          manualOverride: pesos(52),
          useUtangPrices: true,
        ),
        pesos(52),
      );
    });
  });

  group('usesUtangPrices', () {
    test('utang method always uses utang prices', () {
      expect(
        usesUtangPrices(
          method: PaymentMethod.utang,
          cashShortfallDetected: false,
          customerSelected: false,
        ),
        isTrue,
      );
    });

    test('cash shortfall switches only after a suki is chosen', () {
      expect(
        usesUtangPrices(
          method: PaymentMethod.cash,
          cashShortfallDetected: true,
          customerSelected: false,
        ),
        isFalse,
      );
      expect(
        usesUtangPrices(
          method: PaymentMethod.cash,
          cashShortfallDetected: true,
          customerSelected: true,
        ),
        isTrue,
      );
    });

    test('cash and ewallet without shortfall keep normal prices', () {
      for (final method in [PaymentMethod.cash, PaymentMethod.ewallet]) {
        expect(
          usesUtangPrices(
            method: method,
            cashShortfallDetected: false,
            customerSelected: true,
          ),
          isFalse,
        );
      }
    });
  });

  group('resolveCheckoutLines totals and shortage', () {
    final products = [
      stockedProduct('bigas', 50, utangPrice: 55),
      stockedProduct('asin', 10),
    ];
    const cart = {'bigas': Quantity.whole(2), 'asin': Quantity.whole(1)};

    test('totals differ between cash and utang prices', () {
      final cashLines = resolveCheckoutLines(
        cart: cart,
        products: products,
        manualOverrides: const {},
        useUtangPrices: false,
      );
      final utangLines = resolveCheckoutLines(
        cart: cart,
        products: products,
        manualOverrides: const {},
        useUtangPrices: true,
      );
      expect(sumCheckoutLines(cashLines, Currency.php), pesos(110));
      expect(sumCheckoutLines(utangLines, Currency.php), pesos(120));
      expect(utangLines.first.usesUtangPrice, isTrue);
      expect(utangLines.first.saleUnitPriceOverride, pesos(55));
      expect(utangLines.last.usesUtangPrice, isFalse);
      expect(utangLines.last.saleUnitPriceOverride, isNull);
      expect(cashLines.first.saleUnitPriceOverride, isNull);
    });

    test('a manual override wins and is not marked as utang price', () {
      final lines = resolveCheckoutLines(
        cart: cart,
        products: products,
        manualOverrides: {'bigas': pesos(52)},
        useUtangPrices: true,
      );
      expect(lines.first.subtotal, pesos(104));
      expect(lines.first.usesUtangPrice, isFalse);
      expect(lines.first.saleUnitPriceOverride, pesos(52));
    });

    test('shortage is the utang total minus the cash given', () {
      expect(
        resolveCashShortfall(
          method: PaymentMethod.cash,
          cashTotal: pesos(110),
          utangTotal: pesos(120),
          cashReceived: pesos(100),
        ),
        pesos(20),
      );
    });

    test('cash covering the normal total is not a shortfall', () {
      expect(
        resolveCashShortfall(
          method: PaymentMethod.cash,
          cashTotal: pesos(110),
          utangTotal: pesos(120),
          cashReceived: pesos(115),
        ),
        isNull,
      );
    });

    test('utang method has no cash shortfall', () {
      expect(
        resolveCashShortfall(
          method: PaymentMethod.utang,
          cashTotal: pesos(110),
          utangTotal: pesos(120),
          cashReceived: pesos(100),
        ),
        isNull,
      );
    });
  });
}
