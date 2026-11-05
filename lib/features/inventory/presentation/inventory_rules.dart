import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/expiry_status.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/formatters.dart';

abstract final class InventoryRules {
  static bool hasDuplicateName(
    String enteredName,
    Iterable<StockedProduct> products, {
    String? excludeProductId,
  }) {
    final normalized = enteredName.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return products.any(
      (item) =>
          item.product.id != excludeProductId &&
          item.product.name.trim().toLowerCase() == normalized,
    );
  }

  static bool isExpiringSoon(StockedProduct item, LocalDay today) =>
      ExpiryRules.statusFor(item.product.expiryDay, today) != null;

  static int lowStockCount(Iterable<StockedProduct> products) =>
      products.where((item) => item.isLowOnStock).length;

  static List<StockedProduct> shoppingItems(
    Iterable<StockedProduct> products,
  ) => [
    for (final item in products)
      if (item.tracksStock && (item.isLowOnStock || !item.stock.isPositive))
        item,
  ];

  static int buyAmount(StockedProduct item) {
    final alertWhole = (item.product.lowStockAt?.milli ?? 0) ~/ 1000;
    final target = alertWhole * 2 > 1 ? alertWhole * 2 : 1;
    final currentWhole = (item.stock.milli + 999) ~/ 1000;
    final needed = target - currentWhole;
    return needed < 1 ? 1 : needed;
  }

  static String buildShoppingListText({
    required AppLocalizations localizations,
    required String storeName,
    required Iterable<StockedProduct> products,
  }) {
    final lines = <String>[storeName, localizations.shoppingListHeader];
    for (final item in shoppingItems(products)) {
      lines.add(
        localizations.shoppingListLine(
          item.product.name,
          buyAmount(item).toString(),
          localizedUnit(localizations, item.product.unit),
        ),
      );
    }
    return lines.join('\n');
  }
}
