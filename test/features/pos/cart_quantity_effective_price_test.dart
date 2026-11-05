import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/pos/presentation/cart_quantity_dialog.dart';
import 'package:tinda360/features/pos/presentation/checkout_utang_pricing.dart';
import 'package:tinda360/l10n/app_localizations.dart';

const Money _cashPrice = Money(5000, Currency.php);
const Money _utangPrice = Money(5500, Currency.php);

final StockedProduct _kiloRice = StockedProduct(
  product: Product(
    id: 'rice',
    name: 'Bigas Dinorado',
    unit: ProductUnit.kilo,
    price: _cashPrice,
    cost: const Money(4200, Currency.php),
    utangPrice: _utangPrice,
  ),
  stock: const Quantity.whole(10),
);

Future<Quantity?> _typeAmount(
  WidgetTester tester, {
  required Money? unitPrice,
  required String amountText,
}) async {
  Quantity? chosen;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              chosen = await showCartQuantityDialog(
                context,
                stocked: _kiloRice,
                currentQuantity: const Quantity.whole(1),
                unitPrice: unitPrice,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Amount (₱)'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('cartQuantityField')),
    amountText,
  );
  await tester.pump();
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
  return chosen;
}

void main() {
  testWidgets('amount mode divides by the utang price when one is passed', (
    tester,
  ) async {
    final chosen = await _typeAmount(
      tester,
      unitPrice: _utangPrice,
      amountText: '55',
    );
    expect(chosen, const Quantity.whole(1));
  });

  testWidgets('amount mode keeps the normal price when none is passed', (
    tester,
  ) async {
    final chosen = await _typeAmount(
      tester,
      unitPrice: null,
      amountText: '55',
    );
    expect(chosen, const Quantity.milli(1100));
  });

  test('checkout line exposes the utang price as its effective price', () {
    final utangLines = resolveCheckoutLines(
      cart: {'rice': const Quantity.whole(1)},
      products: [_kiloRice],
      manualOverrides: const {},
      useUtangPrices: true,
    );
    final cashLines = resolveCheckoutLines(
      cart: {'rice': const Quantity.whole(1)},
      products: [_kiloRice],
      manualOverrides: const {},
      useUtangPrices: false,
    );
    final overriddenLines = resolveCheckoutLines(
      cart: {'rice': const Quantity.whole(1)},
      products: [_kiloRice],
      manualOverrides: const {'rice': Money(4000, Currency.php)},
      useUtangPrices: true,
    );
    expect(utangLines.single.effectiveUnitPrice, _utangPrice);
    expect(cashLines.single.effectiveUnitPrice, _cashPrice);
    expect(
      overriddenLines.single.effectiveUnitPrice,
      const Money(4000, Currency.php),
    );
  });
}
