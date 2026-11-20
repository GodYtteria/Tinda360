import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/pos/presentation/checkout_sheet.dart';
import 'package:tinda360/features/pos/presentation/pos_cart_notifier.dart';
import 'package:tinda360/l10n/app_delegates.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/services/store_sounds.dart';

import '../../support/recording_app_log.dart';

final class _RecordingSoundOutput implements StoreSoundOutput {
  final List<StoreSound> played = [];

  @override
  Future<void> play(StoreSound sound) async => played.add(sound);
}

final class _AlwaysOnSettingStore implements StoreSoundSettingStore {
  @override
  Future<bool> read() async => true;

  @override
  Future<void> write({required bool enabled}) async {}
}

StockedProduct _product({required int stock}) => StockedProduct(
  product: const Product(
    id: 'kape',
    name: 'Kape',
    unit: ProductUnit.piece,
    price: Money(1000, Currency.php),
    cost: Money(800, Currency.php),
  ),
  stock: Quantity.whole(stock),
);

void main() {
  Future<(List<StoreSound>, bool)> tapAdd(
    WidgetTester tester,
    StockedProduct item,
  ) async {
    final output = _RecordingSoundOutput();
    final log = RecordingAppLog();
    final container = ProviderContainer(
      overrides: [
        storeSoundOutputProvider.overrideWithValue(output),
        storeSoundSettingStoreProvider.overrideWithValue(
          _AlwaysOnSettingStore(),
        ),
        appLogProvider.overrideWithValue(log),
      ],
    );
    addTearDown(container.dispose);
    late bool added;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ScaffoldMessenger(
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => added = addToCartOrWarn(
                    context,
                    container.read(posCartProvider.notifier),
                    item,
                  ),
                  child: const Text('add'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
    expect(log.events, isEmpty);
    return (output.played, added);
  }

  testWidgets('adding a product in stock plays the add-to-cart sound', (
    tester,
  ) async {
    final (played, added) = await tapAdd(tester, _product(stock: 5));
    expect(added, isTrue);
    expect(played, [StoreSound.addedToCart]);
  });

  testWidgets('a product at its stock limit plays the out-of-stock sound', (
    tester,
  ) async {
    final (played, added) = await tapAdd(tester, _product(stock: 0));
    expect(added, isFalse);
    expect(played, [StoreSound.outOfStock]);
  });
}
