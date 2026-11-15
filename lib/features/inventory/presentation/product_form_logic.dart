import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/shared/widgets/formatters.dart';

/// Pure form-parsing and profit helpers for [ProductSheet].
abstract final class ProductFormLogic {
  /// Computes live profit per unit from raw [priceInput] and [costInput].
  /// Returns null if either input cannot be parsed as a valid non-negative amount.
  static Money? computeProfitPerSale({
    required String priceInput,
    required String costInput,
    required Currency currency,
  }) {
    final price = parseMoneyInput(priceInput, currency);
    final cost = parseMoneyInput(costInput, currency);
    if (price == null || cost == null) return null;
    return price - cost;
  }

  /// Parses a non-negative whole-unit quantity from [rawInput], or returns null
  /// when blank or invalid.
  static Quantity? parseWholeQuantity(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0) return null;
    return Quantity.whole(parsed);
  }

  /// Builds a [ProductDraft] from raw form inputs.
  ///
  /// Missing or unparseable price/cost default to `-1` minor units so the
  /// repository returns `ProductAmountInvalid` consistently.
  static ProductDraft buildDraft({
    required String name,
    required ProductUnit unit,
    required String priceInput,
    required String costInput,
    required Currency currency,
    String categoryInput = '',
    String barcodeInput = '',
    String lowStockInput = '',
    Quantity initialStock = Quantity.zero,
  }) {
    final invalidAmount = Money(-1, currency);
    final price = parseMoneyInput(priceInput, currency) ?? invalidAmount;
    final cost = parseMoneyInput(costInput, currency) ?? invalidAmount;
    final trimmedCategory = categoryInput.trim();
    final trimmedBarcode = barcodeInput.trim();
    final trimmedLowStock = lowStockInput.trim();

    final lowStockAt = trimmedLowStock.isEmpty
        ? null
        : (parseWholeQuantity(trimmedLowStock) ?? const Quantity.milli(-1));

    return ProductDraft(
      name: name,
      unit: unit,
      price: price,
      cost: cost,
      categoryId: trimmedCategory.isEmpty ? null : trimmedCategory,
      barcode: trimmedBarcode.isEmpty ? null : trimmedBarcode,
      lowStockAt: lowStockAt,
      initialStock: initialStock,
    );
  }
}
