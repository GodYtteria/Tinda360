import 'package:tinda360/core/calendar/local_day.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/shared/widgets/formatters.dart';

abstract final class ProductFormLogic {
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

  static Quantity? parseWholeQuantity(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0) return null;
    return Quantity.whole(parsed);
  }

  static String decimalText(Quantity quantity) {
    if (quantity.isWhole) {
      return (quantity.milli ~/ Quantity.milliPerUnit).toString();
    }
    final text = (quantity.milli / Quantity.milliPerUnit).toStringAsFixed(3);
    return text.replaceFirst(RegExp(r'0+$'), '');
  }

  static Quantity? parseQuantity(
    String rawInput, {
    required bool allowsFraction,
  }) {
    if (!allowsFraction) return parseWholeQuantity(rawInput);
    final trimmed = rawInput.trim();
    if (!RegExp(r'^\d{1,6}(\.\d{1,3})?$').hasMatch(trimmed)) return null;
    return Quantity.milli(
      (double.parse(trimmed) * Quantity.milliPerUnit).round(),
    );
  }

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
    String utangPriceInput = '',
    bool tracksStock = true,
    LocalDay? expiryDay,
  }) {
    final invalidAmount = Money(-1, currency);
    final price = parseMoneyInput(priceInput, currency) ?? invalidAmount;
    final cost = parseMoneyInput(costInput, currency) ?? invalidAmount;
    final trimmedCategory = categoryInput.trim();
    final trimmedBarcode = barcodeInput.trim();
    final trimmedLowStock = lowStockInput.trim();
    final trimmedUtangPrice = utangPriceInput.trim();

    final lowStockAt = (trimmedLowStock.isEmpty || !tracksStock)
        ? null
        : (parseQuantity(
                trimmedLowStock,
                allowsFraction: unit.allowsFraction,
              ) ??
              const Quantity.milli(-1));

    return ProductDraft(
      name: name,
      unit: unit,
      price: price,
      cost: cost,
      categoryId: trimmedCategory.isEmpty ? null : trimmedCategory,
      barcode: trimmedBarcode.isEmpty ? null : trimmedBarcode,
      lowStockAt: lowStockAt,
      initialStock: tracksStock ? initialStock : Quantity.zero,
      tracksStock: tracksStock,
      expiryDay: expiryDay,
      utangPrice: trimmedUtangPrice.isEmpty
          ? null
          : (parseMoneyInput(trimmedUtangPrice, currency) ?? invalidAmount),
    );
  }

  static bool isUtangPriceInputValid(String rawInput, Currency currency) {
    final trimmed = rawInput.trim();
    return trimmed.isEmpty || parseMoneyInput(trimmed, currency) != null;
  }
}
