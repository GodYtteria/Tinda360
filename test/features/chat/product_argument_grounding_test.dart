import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/chat/data/product_argument_grounding.dart';

StockedProduct _product(String id, String name) => StockedProduct(
  product: Product(
    id: id,
    name: name,
    unit: ProductUnit.piece,
    price: const Money(2000, Currency.php),
    cost: const Money(1500, Currency.php),
  ),
  stock: const Quantity.whole(10),
);

final _inventory = [
  _product('p1', 'Lucky Me Pancit Canton'),
  _product('p2', 'Bingo biscuit'),
  _product('p3', 'Datu Puti suka'),
];

void main() {
  test('a wrong product name from the model is replaced by the one asked', () {
    final grounded = groundProductArgument(
      {'product_name': 'Datu Puti suka'},
      'ilan pa ang natitirang Bingo biscuit sa estante',
      _inventory,
    );
    expect(grounded, {'product_name': 'Bingo biscuit'});
  });

  test('the name comes from the question words, matched to inventory', () {
    final grounded = groundProductArgument(
      {'product_name': 'ice candy'},
      'ilang araw pa bago maubos ang pancit canton',
      _inventory,
    );
    expect(grounded, {'product_name': 'pancit canton'});
  });

  test('a product that is not in inventory gives no arguments', () {
    expect(
      groundProductArgument(
        {'product_name': 'Datu Puti suka'},
        'gaano pa katagal bago maubos ang uling ko',
        _inventory,
      ),
      isNull,
    );
    expect(
      groundProductArgument({'product_name': 'kape'}, '', _inventory),
      isNull,
    );
    expect(
      groundProductArgument(
        {'product_name': 'kape'},
        'magkano ang kape',
        const [],
      ),
      isNull,
    );
  });

  test('other tools keep the model arguments untouched', () {
    final arguments = {'timeframe': 'week'};
    expect(
      groundProductArgument(arguments, 'benta this week', _inventory),
      same(arguments),
    );
    expect(groundProductArgument(const {}, 'kumusta', _inventory), isEmpty);
  });

  test('other arguments survive grounding', () {
    expect(
      groundProductArgument(
        {'product_name': 'x', 'days': 7},
        'kailan mauubos ang Bingo biscuit',
        _inventory,
      ),
      {'product_name': 'Bingo biscuit', 'days': 7},
    );
  });
}
