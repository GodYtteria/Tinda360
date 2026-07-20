import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/l10n/app_localizations.dart';

/// Formats [money] as `₱12.50` (always 2 decimals for PHP).
String formatMoney(Money money) {
  final isNegative = money.isNegative;
  final absoluteMinor = money.minorUnits.abs();
  final major = absoluteMinor ~/ money.currency.minorPerMajor;
  final minor = absoluteMinor % money.currency.minorPerMajor;
  final minorText = minor.toString().padLeft(money.currency.exponent, '0');
  final symbol = switch (money.currency) {
    Currency.php => '₱',
  };
  final prefix = isNegative ? '-' : '';
  return '$prefix$symbol$major.$minorText';
}

/// Parses a user-entered peso string like `12.50` or `50` into [Money].
Money? parseMoneyInput(String rawInput, Currency currency) {
  final trimmed = rawInput.trim().replaceAll(',', '');
  if (trimmed.isEmpty) return null;
  final parsed = double.tryParse(trimmed);
  if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed < 0) {
    return null;
  }
  final minorUnits = (parsed * currency.minorPerMajor).round();
  return Money(minorUnits, currency);
}

/// Formats [quantity] as whole numbers for countable units or fractions for
/// kilo/liter (e.g. `¼`, `½`, `¾`, `1 ½`).
String formatQuantity(Quantity quantity, ProductUnit unit) {
  final milli = quantity.milli;
  if (!unit.allowsFraction || milli % Quantity.milliPerUnit == 0) {
    return (milli ~/ Quantity.milliPerUnit).toString();
  }
  final sign = milli < 0 ? '-' : '';
  final whole = milli.abs() ~/ Quantity.milliPerUnit;
  final remainder = milli.abs() % Quantity.milliPerUnit;
  final fraction = switch (remainder) {
    250 => '¼',
    500 => '½',
    750 => '¾',
    _ => (milli / Quantity.milliPerUnit).toStringAsFixed(2),
  };
  if (remainder != 250 && remainder != 500 && remainder != 750) {
    return fraction;
  }
  return whole == 0 ? '$sign$fraction' : '$sign$whole $fraction';
}

/// Localizes [unit] using ARB strings.
String localizedUnit(AppLocalizations localizations, ProductUnit unit) =>
    switch (unit) {
      ProductUnit.piece => localizations.unitPiece,
      ProductUnit.pack => localizations.unitPack,
      ProductUnit.sachet => localizations.unitSachet,
      ProductUnit.can => localizations.unitCan,
      ProductUnit.bottle => localizations.unitBottle,
      ProductUnit.bar => localizations.unitBar,
      ProductUnit.bag => localizations.unitBag,
      ProductUnit.kilo => localizations.unitKilo,
      ProductUnit.liter => localizations.unitLiter,
    };

/// Maps a domain [Failure] via its `code` to a localized user message.
String localizedFailureMessage(
  AppLocalizations localizations,
  Failure failure,
) => switch (failure.code) {
  'sale.no_lines' => localizations.failureSaleNoLines,
  'sale.quantity_invalid' => localizations.failureSaleQuantityInvalid,
  'sale.product_not_found' => localizations.failureSaleProductNotFound,
  'sale.customer_required' => localizations.failureSaleCustomerRequired,
  'sale.customer_not_found' => localizations.failureSaleCustomerNotFound,
  'sale.payment_too_low' => localizations.failureSalePaymentTooLow,
  'sale.store_unavailable' => localizations.failureSaleStoreUnavailable,
  'product.name_required' => localizations.failureProductNameRequired,
  'product.amount_invalid' => localizations.failureProductAmountInvalid,
  'product.quantity_invalid' => localizations.failureProductQuantityInvalid,
  'product.barcode_taken' => localizations.failureProductBarcodeTaken,
  'product.not_found' => localizations.failureProductNotFound,
  'product.store_unavailable' => localizations.failureProductStoreUnavailable,
  'customer.name_required' => localizations.failureCustomerNameRequired,
  'customer.not_found' => localizations.failureCustomerNotFound,
  'customer.amount_invalid' => localizations.failureCustomerAmountInvalid,
  'customer.payment_exceeds_balance' =>
    localizations.failureCustomerPaymentExceedsBalance,
  'customer.store_unavailable' => localizations.failureCustomerStoreUnavailable,
  'store.name_required' => localizations.failureStoreNameRequired,
  'store.unavailable' => localizations.failureStoreUnavailable,
  _ => localizations.homeLoadFailed,
};
