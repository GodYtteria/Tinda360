import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/l10n/app_localizations.dart';

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

Money? parseMoneyInput(String rawInput, Currency currency) {
  final trimmed = rawInput.trim().replaceAll(_thousandsSeparator, '');
  final match = _moneyInputPattern.firstMatch(trimmed);
  if (match == null) return null;
  final majorText = match.group(1)!;
  final fractionText = match.group(2) ?? '';
  if (majorText.isEmpty && fractionText.isEmpty) return null;
  final majorUnits = majorText.isEmpty ? 0 : int.parse(majorText);
  final fraction = fractionText.padRight(currency.exponent, '0');
  if (fraction.length > currency.exponent) return null;
  final minorFromFraction = fraction.isEmpty ? 0 : int.parse(fraction);
  return Money(
    majorUnits * currency.minorPerMajor + minorFromFraction,
    currency,
  );
}

final RegExp _thousandsSeparator = RegExp(r',(?=\d{3}(?:\D|$))');
final RegExp _moneyInputPattern = RegExp(r'^(\d{0,12})(?:\.(\d*))?$');

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
  'sale.paid_now_invalid' => localizations.failureSalePaidNowInvalid,
  'sale.interest_invalid' => localizations.failureSaleInterestInvalid,
  'sale.price_invalid' => localizations.failureSalePriceInvalid,
  'sale.insufficient_stock' => localizations.failureSaleInsufficientStock,
  'sale.not_found' => localizations.failureSaleNotFound,
  'sale.void_after_payment' => localizations.failureSaleVoidAfterPayment,
  'sale.void_after_return' => localizations.failureSaleVoidAfterReturn,
  'sale.store_unavailable' => localizations.failureSaleStoreUnavailable,
  'sale_return.nothing_selected' =>
    localizations.failureSaleReturnNothingSelected,
  'sale_return.quantity_invalid' =>
    localizations.failureSaleReturnQuantityInvalid,
  'sale_return.too_many' => localizations.failureSaleReturnTooMany,
  'sale_return.sale_voided' => localizations.failureSaleReturnSaleVoided,
  'sale_return.not_found' => localizations.failureSaleReturnNotFound,
  'sale_return.store_unavailable' =>
    localizations.failureSaleReturnStoreUnavailable,
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
  'customer.interest_rate_not_set' =>
    localizations.failureCustomerInterestRateNotSet,
  'customer.interest_no_balance' =>
    localizations.failureCustomerInterestNoBalance,
  'customer.interest_amount_changed' =>
    localizations.failureCustomerInterestAmountChanged,
  'customer.ledger_entry_not_found' => localizations.failureLedgerEntryNotFound,
  'customer.ledger_entry_already_deleted' =>
    localizations.failureLedgerEntryAlreadyDeleted,
  'customer.ledger_entry_not_deletable' =>
    localizations.failureLedgerEntryNotDeletable,
  'customer.ledger_delete_would_go_negative' =>
    localizations.failureLedgerDeleteWouldGoNegative,
  'customer.has_balance' => localizations.failureCustomerHasBalance,
  'customer.store_unavailable' => localizations.failureCustomerStoreUnavailable,
  'store.name_required' => localizations.failureStoreNameRequired,
  'store.unavailable' => localizations.failureStoreUnavailable,
  _ => localizations.homeLoadFailed,
};

String localizedPaymentMethod(
  AppLocalizations localizations,
  PaymentMethod method,
) => switch (method) {
  PaymentMethod.cash => localizations.checkoutMethodCash,
  PaymentMethod.ewallet => localizations.checkoutMethodEwallet,
  PaymentMethod.utang => localizations.checkoutMethodUtang,
};
