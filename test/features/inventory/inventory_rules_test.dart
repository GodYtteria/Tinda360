import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/expiry_status.dart';
import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/inventory/presentation/inventory_rules.dart';
import 'package:tinda360/l10n/app_localizations_en.dart';
import 'package:tinda360/l10n/app_localizations_fil.dart';

StockedProduct _item({
  String id = 'p1',
  String name = 'Item',
  bool tracksStock = true,
  int stock = 0,
  int? lowStockAt,
}) => StockedProduct(
  product: Product(
    id: id,
    name: name,
    unit: ProductUnit.piece,
    price: const Money(100, Currency.php),
    cost: const Money(50, Currency.php),
    lowStockAt: lowStockAt == null ? null : Quantity.whole(lowStockAt),
    tracksStock: tracksStock,
  ),
  stock: Quantity.whole(stock),
);

void main() {
  const today = LocalDay(20000);

  group('ExpiryRules.statusFor', () {
    test('null expiry has no status', () {
      expect(ExpiryRules.statusFor(null, today), isNull);
    });

    test('today is near with zero days', () {
      final status = ExpiryRules.statusFor(today, today);
      expect((status! as ExpiryNear).daysLeft, 0);
    });

    test('14 days is near, 15 days is not', () {
      final near = ExpiryRules.statusFor(today.plusDays(14), today);
      expect((near! as ExpiryNear).daysLeft, 14);
      expect(ExpiryRules.statusFor(today.plusDays(15), today), isNull);
    });

    test('yesterday is expired', () {
      expect(
        ExpiryRules.statusFor(today.plusDays(-1), today),
        isA<ExpiryExpired>(),
      );
    });

    test('iso parse and format round trip and reject bad dates', () {
      final day = ExpiryRules.parseIso('2026-02-28')!;
      expect(ExpiryRules.formatIso(day), '2026-02-28');
      expect(ExpiryRules.parseIso('2026-02-30'), isNull);
      expect(ExpiryRules.parseIso('28/02/2026'), isNull);
    });
  });

  group('hasDuplicateName', () {
    final products = [_item(id: 'a', name: 'Kape')];

    test('matches case-insensitive and trimmed', () {
      expect(InventoryRules.hasDuplicateName('  kAPE ', products), isTrue);
    });

    test('ignores the product being edited and blank names', () {
      expect(
        InventoryRules.hasDuplicateName(
          'Kape',
          products,
          excludeProductId: 'a',
        ),
        isFalse,
      );
      expect(InventoryRules.hasDuplicateName('   ', products), isFalse);
      expect(InventoryRules.hasDuplicateName('Kapeng', products), isFalse);
    });
  });

  group('shopping list', () {
    final english = AppLocalizationsEn();
    final filipino = AppLocalizationsFil();

    test('target math: max(alert x 2, 1) minus current, floor 1', () {
      expect(
        InventoryRules.buyAmount(_item(stock: 1, lowStockAt: 5)),
        9,
      );
      expect(InventoryRules.buyAmount(_item()), 1);
      expect(
        InventoryRules.buyAmount(_item(stock: 5, lowStockAt: 5)),
        5,
      );
      expect(
        InventoryRules.buyAmount(_item(lowStockAt: 0)),
        1,
      );
    });

    test('lists low and out of stock tracked items, excludes others', () {
      final text = InventoryRules.buildShoppingListText(
        localizations: english,
        storeName: 'Aling Nena',
        products: [
          _item(id: 'a', name: 'Kape', stock: 1, lowStockAt: 5),
          _item(id: 'b', name: 'Load', tracksStock: false, lowStockAt: 5),
          _item(id: 'c', name: 'Asin', stock: 50, lowStockAt: 5),
          _item(id: 'd', name: 'Sabon'),
        ],
      );
      final lines = text.split('\n');
      expect(lines.first, 'Aling Nena');
      expect(lines, contains('- Kape: buy 9 piece'));
      expect(lines, contains('- Sabon: buy 1 piece'));
      expect(text, isNot(contains('Load')));
      expect(text, isNot(contains('Asin')));
    });

    test('filipino text uses filipino strings', () {
      final text = InventoryRules.buildShoppingListText(
        localizations: filipino,
        storeName: 'Tindahan',
        products: [_item(name: 'Kape', lowStockAt: 2)],
      );
      expect(text, contains(filipino.shoppingListHeader));
      expect(text, contains('Kape'));
      expect(filipino.shoppingListHeader, isNot(english.shoppingListHeader));
    });

    test('nothing low gives an empty item list', () {
      expect(
        InventoryRules.shoppingItems([_item(stock: 10, lowStockAt: 2)]),
        isEmpty,
      );
    });
  });
}
