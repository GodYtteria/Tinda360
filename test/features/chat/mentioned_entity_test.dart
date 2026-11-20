import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/customers/customer.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/chat/presentation/chat_reply_builders.dart';

StockedProduct _product(String name) => StockedProduct(
  product: Product(
    id: name,
    name: name,
    unit: ProductUnit.piece,
    price: const Money(2000, Currency.php),
    cost: const Money(1500, Currency.php),
  ),
  stock: const Quantity.whole(10),
);

CustomerBalance _customer(String name) => CustomerBalance(
  customer: Customer(id: name, name: name),
  balance: const Money(5000, Currency.php),
);

void main() {
  test('a name inside a longer word is not a mention', () {
    expect(findMentionedCustomer('benta ngayon', [_customer('Ben')]), isNull);
    expect(findMentionedProduct('price of coke', [_product('Ice')]), isNull);
  });

  test('a whole-word name is a mention', () {
    expect(
      findMentionedCustomer('magkano utang ni ben', [_customer('Ben')]),
      isNotNull,
    );
    expect(
      findMentionedProduct('magkano ang ice', [_product('Ice')])?.product.name,
      'Ice',
    );
  });

  test('the longest matching product name wins', () {
    final products = [_product('Coke'), _product('Coke Zero')];
    expect(
      findMentionedProduct('magkano coke zero', products)?.product.name,
      'Coke Zero',
    );
    expect(
      findMentionedProduct('magkano coke', products)?.product.name,
      'Coke',
    );
  });

  test('names with punctuation or ñ match the normalized query', () {
    expect(
      findMentionedProduct('magkano pi a colada', [_product('Piña Colada')])
          ?.product.name,
      'Piña Colada',
    );
    expect(
      findMentionedProduct('presyo ng coca cola 1 5l', [
        _product('Coca-Cola 1.5L'),
      ])?.product.name,
      'Coca-Cola 1.5L',
    );
  });

  test('empty query and short names never match', () {
    expect(findMentionedProduct('', [_product('Coke')]), isNull);
    expect(findMentionedCustomer('si al', [_customer('Al')]), isNull);
  });
}
