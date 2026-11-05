import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/pos/data/popular_sort.dart';

StockedProduct stocked(String id, String name) => StockedProduct(
  product: Product(
    id: id,
    name: name,
    unit: ProductUnit.piece,
    price: const Money(100, Currency.php),
    cost: const Money(50, Currency.php),
  ),
  stock: const Quantity.whole(5),
);

void main() {
  test('most sold first, ties by name, unsold after in name order', () {
    final sorted = sortProductsByPopularity(
      [
        stocked('a', 'Apple'),
        stocked('b', 'Banana'),
        stocked('c', 'Cola'),
        stocked('d', 'Dalandan'),
      ],
      {'c': 9000, 'd': 9000, 'b': 1000},
    );
    expect(sorted.map((item) => item.product.id), ['c', 'd', 'b', 'a']);
  });

  test('empty popularity falls back to case-insensitive name order', () {
    final sorted = sortProductsByPopularity([
      stocked('x', 'zebra'),
      stocked('y', 'Apple'),
    ], const {});
    expect(sorted.map((item) => item.product.id), ['y', 'x']);
  });

  test('does not mutate input', () {
    final input = [stocked('x', 'B'), stocked('y', 'A')];
    sortProductsByPopularity(input, const {});
    expect(input.first.product.id, 'x');
  });
}
