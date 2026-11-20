import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/customers/customer.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/chat/data/entity_resolver.dart';

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

CustomerBalance _customer(String id, String name) => CustomerBalance(
  customer: Customer(id: id, name: name),
  balance: const Money(5000, Currency.php),
);

List<String> _ids(EntityResolution resolution) => [
  for (final candidate in resolution.candidates) candidate.id,
];

void main() {
  const resolver = EntityResolver();

  test('exact full name resolves to a single product', () {
    final resolution = resolver.resolveProduct('magkano ang bigas', [
      _product('p1', 'Bigas'),
      _product('p2', 'Asukal'),
    ]);
    expect(resolution.kind, ResolutionKind.single);
    expect(resolution.single?.id, 'p1');
    expect(resolution.mention, 'bigas');
  });

  test('a name inside a longer word is not a mention', () {
    expect(
      resolver.resolveCustomer('benta ngayon', [_customer('c1', 'Ben')]).kind,
      ResolutionKind.none,
    );
    expect(
      resolver.resolveProduct('price of coke', [_product('p1', 'Ice')]).kind,
      ResolutionKind.none,
    );
  });

  test('punctuation, case and enye are folded on both sides', () {
    final punctuation = resolver.resolveProduct('Magkano COCA-COLA 1.5L?', [
      _product('p1', 'coca cola 1.5l'),
    ]);
    expect(punctuation.single?.id, 'p1');
    expect(punctuation.mention, 'COCA-COLA 1.5L');
    final folded = resolver.resolveCustomer('utang ni NIÑA', [
      _customer('c1', 'Nina'),
    ]);
    expect(folded.single?.id, 'c1');
    final reverse = resolver.resolveCustomer('utang ni nina', [
      _customer('c1', 'Niña'),
    ]);
    expect(reverse.single?.id, 'c1');
    final accent = resolver.resolveProduct('café', [_product('p1', 'Cafe')]);
    expect(accent.single?.id, 'p1');
  });

  test('a partial mention matching several products is ambiguous', () {
    final resolution = resolver.resolveProduct('magkano coke', [
      _product('p1', 'Coke Mismo'),
      _product('p2', 'Coke 1.5L'),
      _product('p3', 'Sprite'),
    ]);
    expect(resolution.kind, ResolutionKind.ambiguous);
    expect(_ids(resolution), ['p2', 'p1']);
    expect(resolution.single, isNull);
    expect(resolution.mention, 'coke');
  });

  test('a multi word partial mention matches a longer name', () {
    final resolution = resolver.resolveProduct('stock ng lucky me', [
      _product('p1', 'Lucky Me Pancit Canton'),
      _product('p2', 'Piattos'),
    ]);
    expect(resolution.kind, ResolutionKind.single);
    expect(resolution.single?.id, 'p1');
    expect(resolution.mention, 'lucky me');
  });

  test('an exact full name beats partial matches', () {
    final resolution = resolver.resolveProduct('magkano coke', [
      _product('p1', 'Coke Mismo'),
      _product('p2', 'Coke'),
      _product('p3', 'Coke 1.5L'),
    ]);
    expect(resolution.kind, ResolutionKind.single);
    expect(resolution.single?.id, 'p2');
  });

  test('the longest full name wins', () {
    final resolution = resolver.resolveProduct('magkano coke zero', [
      _product('p1', 'Coke'),
      _product('p2', 'Coke Zero'),
    ]);
    expect(resolution.kind, ResolutionKind.single);
    expect(resolution.single?.id, 'p2');
  });

  test('equally long full names are ambiguous', () {
    final resolution = resolver.resolveProduct('bigas at gatas', [
      _product('p1', 'Bigas'),
      _product('p2', 'Gatas'),
      _product('p3', 'Kape'),
    ]);
    expect(resolution.kind, ResolutionKind.ambiguous);
    expect(_ids(resolution), ['p1', 'p2']);
  });

  test('a longer partial mention beats a shorter partial mention', () {
    final resolution = resolver.resolveProduct('coke zero', [
      _product('p1', 'Coke Mismo'),
      _product('p2', 'Coke Zero 1L'),
    ]);
    expect(resolution.kind, ResolutionKind.single);
    expect(resolution.single?.id, 'p2');
  });

  test('candidates are capped at the maximum', () {
    final resolution = resolver.resolveProduct('coke', [
      _product('p1', 'Coke A'),
      _product('p2', 'Coke B'),
      _product('p3', 'Coke C'),
      _product('p4', 'Coke D'),
      _product('p5', 'Coke E'),
    ]);
    expect(resolution.kind, ResolutionKind.ambiguous);
    expect(resolution.candidates, hasLength(EntityResolver.maximumCandidates));
    expect(_ids(resolution), ['p1', 'p2', 'p3']);
  });

  test('empty text and empty lists resolve to none', () {
    final emptyText = resolver.resolveProduct('   ', [_product('p1', 'Coke')]);
    expect(emptyText.kind, ResolutionKind.none);
    expect(emptyText.candidates, isEmpty);
    expect(emptyText.single, isNull);
    final emptyList = resolver.resolveProduct('  coke ', []);
    expect(emptyList.kind, ResolutionKind.none);
    expect(emptyList.mention, 'coke');
    expect(resolver.resolveCustomer('ben', []).kind, ResolutionKind.none);
    expect(resolver.resolveCustomer('', []).kind, ResolutionKind.none);
  });

  test('entries with empty or whitespace names are ignored', () {
    final resolution = resolver.resolveProduct('magkano coke', [
      _product('p1', ''),
      _product('p2', '   '),
      _product('p3', '---'),
      _product('p4', 'Coke'),
    ]);
    expect(resolution.kind, ResolutionKind.single);
    expect(resolution.single?.id, 'p4');
    expect(
      resolver.resolveCustomer('utang ni ben', [_customer('c1', ' ')]).kind,
      ResolutionKind.none,
    );
  });

  test('a customer is found by first name behind an honorific', () {
    final resolution = resolver.resolveCustomer('utang ni aling nena', [
      _customer('c1', 'Nena Cruz'),
      _customer('c2', 'Ben Reyes'),
    ]);
    expect(resolution.kind, ResolutionKind.single);
    expect(resolution.single?.id, 'c1');
    expect(resolution.mention, 'nena');
  });

  test('a mention under three letters does not partial match', () {
    expect(
      resolver.resolveCustomer('utang ni bo', [
        _customer('c1', 'Bo Cruz'),
      ]).kind,
      ResolutionKind.none,
    );
    expect(
      resolver.resolveProduct('magkano ang 7 up', [
        _product('p1', '7 Up Lemon'),
      ]).kind,
      ResolutionKind.none,
    );
  });
}
