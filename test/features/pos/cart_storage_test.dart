import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/pos/presentation/cart_price_override_provider.dart';
import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/pos/data/cart_storage.dart';
import 'package:tinda360/features/pos/presentation/pos_cart_notifier.dart';

StockedProduct _stocked(String id, Quantity stock) => StockedProduct(
  product: Product(
    id: id,
    name: id,
    unit: ProductUnit.kilo,
    price: const Money(5000, Currency.php),
    cost: const Money(4000, Currency.php),
  ),
  stock: stock,
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 100));

void main() {
  late Directory directory;
  late CartStorage storage;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cart_storage_test');
    storage = CartStorage(directoryProvider: () async => directory);
  });

  tearDown(() => directory.delete(recursive: true));

  test(
    'deleteStore removes cart and prices files of that store only',
    () async {
      await storage.write('store-a', {'rice': const Quantity.whole(2)});
      await storage.writePrices('store-a', {'rice': 4500});
      await storage.write('store-b', {'rice': const Quantity.whole(1)});
      await storage.writePrices('store-b', {'rice': 100});

      await storage.deleteStore('store-a');

      expect(
        File('${directory.path}/tinda360_cart_store-a.json').existsSync(),
        isFalse,
      );
      expect(
        File('${directory.path}/tinda360_cart_prices_store-a.json')
            .existsSync(),
        isFalse,
      );
      expect(await storage.read('store-b'), isNotEmpty);
      expect(await storage.readPrices('store-b'), {'rice': 100});
    },
  );

  test('price overrides round trip per store and clear when empty', () async {
    await storage.writePrices('store-a', {'rice': 4500, 'coffee': 800});
    await storage.writePrices('store-b', {'rice': 100});

    expect(await storage.readPrices('store-a'), {'rice': 4500, 'coffee': 800});
    expect(await storage.readPrices('store-b'), {'rice': 100});

    await storage.writePrices('store-a', const {});
    expect(await storage.readPrices('store-a'), isEmpty);
    expect(await storage.readPrices('store-b'), {'rice': 100});
  });

  test(
    'reads wait for queued writes so a cleared cart is never revived',
    () async {
      await storage.writePrices('store-a', {'rice': 4500});
      await storage.write('store-a', {'rice': const Quantity.whole(2)});

      final pendingPriceClear = storage.writePrices('store-a', const {});
      final pendingCartClear = storage.write('store-a', const {});
      final prices = storage.readPrices('store-a');
      final cart = storage.read('store-a');

      expect(await prices, isEmpty);
      expect(await cart, isEmpty);
      await pendingPriceClear;
      await pendingCartClear;
    },
  );

  test('corrupt or negative price data reads as no overrides', () async {
    File('${directory.path}/tinda360_cart_prices_store-a.json')
        .writeAsStringSync('{bro');
    expect(await storage.readPrices('store-a'), isEmpty);

    await storage.writePrices('store-a', {'rice': -5, 'tea': 300});
    expect(await storage.readPrices('store-a'), {'tea': 300});
  });

  test('a failed save reaches the caller and later saves still work', () async {
    var directoryRequests = 0;
    final flakyStorage = CartStorage(
      directoryProvider: () async {
        directoryRequests++;
        if (directoryRequests == 1) {
          throw const FileSystemException('storage full');
        }
        return directory;
      },
    );

    await expectLater(
      flakyStorage.write('store-a', {'coffee': const Quantity.whole(2)}),
      throwsA(isA<FileSystemException>()),
    );
    await flakyStorage.write('store-a', {'coffee': const Quantity.whole(3)});
    expect(
      await flakyStorage.read('store-a'),
      {'coffee': const Quantity.whole(3)},
    );
  });

  test('round trip keeps milli quantities', () async {
    await storage.write('store-a', {'rice': const Quantity.milli(2500)});
    final restored = await storage.read('store-a');
    expect(restored, {'rice': const Quantity.milli(2500)});
  });

  test('stores are isolated', () async {
    await storage.write('store-a', {'rice': const Quantity.whole(1)});
    await storage.write('store-b', {'oil': const Quantity.whole(2)});
    expect(await storage.read('store-a'), {'rice': const Quantity.whole(1)});
    expect(await storage.read('store-b'), {'oil': const Quantity.whole(2)});
    expect(await storage.read('store-c'), isEmpty);
  });

  test('corrupt file gives empty cart', () async {
    File('${directory.path}/tinda360_cart_store-a.json')
        .writeAsStringSync('{{nope');
    expect(await storage.read('store-a'), isEmpty);
  });

  test('wrong shaped json and bad quantities are dropped', () async {
    File('${directory.path}/tinda360_cart_store-a.json').writeAsStringSync(
      '{"lines":{"good":1000,"zero":0,"neg":-5,"text":"x","frac":1.5}}',
    );
    expect(await storage.read('store-a'), {'good': const Quantity.whole(1)});
  });

  test('writing empty cart removes the file', () async {
    await storage.write('store-a', {'rice': const Quantity.whole(1)});
    final file = File('${directory.path}/tinda360_cart_store-a.json');
    expect(file.existsSync(), isTrue);
    await storage.write('store-a', const {});
    expect(file.existsSync(), isFalse);
  });

  test(
    'concurrent writes end with the last one and leave no tmp file',
    () async {
      final writes = [
        for (var count = 1; count <= 20; count++)
          storage.write('store-a', {'rice': Quantity.whole(count)}),
      ];
      await Future.wait(writes);
      expect(await storage.read('store-a'), {'rice': const Quantity.whole(20)});
      expect(
        directory.listSync().where((entity) => entity.path.endsWith('.tmp')),
        isEmpty,
      );
    },
  );

  test('unsafe store id cannot escape the directory', () async {
    await storage.write('../evil', {'rice': const Quantity.whole(1)});
    expect(
      directory.listSync().single.path.startsWith(directory.path),
      isTrue,
    );
    expect(await storage.read('../evil'), {'rice': const Quantity.whole(1)});
  });

  group('notifier persistence', () {
    ProviderContainer containerFor(String? storeId) => ProviderContainer(
      overrides: [
        cartStorageProvider.overrideWithValue(storage),
        activeCartStoreIdProvider.overrideWithValue(storeId),
      ],
    );

    test('cart survives a new container and clear removes it', () async {
      final first = containerFor('store-a');
      first.listen(posCartProvider, (previous, next) {});
      await _settle();
      first
          .read(posCartProvider.notifier)
          .setQuantity(
            'rice',
            const Quantity.milli(1500),
            available: const Quantity.whole(10),
          );
      await _settle();
      first.dispose();

      final second = containerFor('store-a');
      second.listen(posCartProvider, (previous, next) {});
      await _settle();
      expect(second.read(posCartProvider), {
        'rice': const Quantity.milli(1500),
      });

      second.read(posCartProvider.notifier).clear();
      await _settle();
      expect(
        File('${directory.path}/tinda360_cart_store-a.json').existsSync(),
        isFalse,
      );
      second.dispose();

      final other = containerFor('store-b');
      other.listen(posCartProvider, (previous, next) {});
      await _settle();
      expect(other.read(posCartProvider), isEmpty);
      other.dispose();
    });

    test('price changes survive a restart and clear with the cart', () async {
      final first = containerFor('store-a');
      first.listen(posCartProvider, (previous, next) {});
      first.listen(cartPriceOverrideProvider, (previous, next) {});
      first
          .read(posCartProvider.notifier)
          .setQuantity(
            'rice',
            const Quantity.whole(2),
            available: const Quantity.whole(9),
          );
      first
          .read(cartPriceOverrideProvider.notifier)
          .setPrice('rice', const Money(4500, Currency.php));
      await _settle();
      await _settle();
      expect(await storage.readPrices('store-a'), {'rice': 4500});
      first.dispose();

      final second = containerFor('store-a');
      second.listen(posCartProvider, (previous, next) {});
      second.listen(cartPriceOverrideProvider, (previous, next) {});
      await _settle();
      await _settle();
      expect(second.read(posCartProvider), {'rice': const Quantity.whole(2)});
      expect(second.read(cartPriceOverrideProvider), {
        'rice': const Money(4500, Currency.php),
      });

      second.read(posCartProvider.notifier).clear();
      await _settle();
      await _settle();
      expect(await storage.readPrices('store-a'), isEmpty);
      second.dispose();
    });

    test('keepWithinStock trims restored cart', () async {
      await storage.write('store-a', {
        'rice': const Quantity.whole(5),
        'gone': const Quantity.whole(1),
        'empty': const Quantity.whole(1),
      });
      final container = containerFor('store-a');
      container.listen(posCartProvider, (previous, next) {});
      container.read(posCartProvider.notifier).keepWithinStock([
        _stocked('rice', const Quantity.whole(2)),
        _stocked('empty', Quantity.zero),
      ]);
      await _settle();
      expect(container.read(posCartProvider), {
        'rice': const Quantity.whole(2),
      });
      await _settle();
      expect(await storage.read('store-a'), {'rice': const Quantity.whole(2)});
      container.dispose();
    });
  });
}
