import 'package:tinda360/core/money/currency.dart';

/// An amount of money as integer minor units of one [currency].
///
/// Never a floating-point value. Mixing currencies is a programming error.
final class Money implements Comparable<Money> {
  /// Creates [minorUnits] of [currency], e.g. `Money(1250, Currency.php)`
  /// for ₱12.50.
  const Money(this.minorUnits, this.currency);

  /// Zero of [currency].
  const Money.zero(this.currency) : minorUnits = 0;

  /// The amount in minor units (centavos for PHP).
  final int minorUnits;

  /// The currency of this amount.
  final Currency currency;

  /// Whether this amount is below zero.
  bool get isNegative => minorUnits < 0;

  /// Whether this amount is above zero.
  bool get isPositive => minorUnits > 0;

  /// The sum of this and [other], which must share the currency.
  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currency);
  }

  /// This minus [other], which must share the currency.
  Money operator -(Money other) {
    _requireSameCurrency(other);
    return Money(minorUnits - other.minorUnits, currency);
  }

  /// Whether this is strictly less than [other].
  bool operator <(Money other) => compareTo(other) < 0;

  /// Whether this is strictly greater than [other].
  bool operator >(Money other) => compareTo(other) > 0;

  @override
  int compareTo(Money other) {
    _requireSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  void _requireSameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError('Currency mismatch: $currency vs ${other.currency}');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => 'Money($minorUnits ${currency.code})';
}
