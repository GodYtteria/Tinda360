/// Currencies the app can store, with their real ISO-4217 minor-unit
/// exponent. Unknown codes are never defaulted.
enum Currency {
  /// Philippine peso: 100 centavos per peso.
  php('PHP', 2);

  const Currency(this.code, this.exponent);

  /// The ISO-4217 alphabetic code, as stored in the database.
  final String code;

  /// The ISO-4217 minor-unit exponent.
  final int exponent;

  /// Minor units per major unit. The only scaling source for money.
  int get minorPerMajor => switch (exponent) {
    0 => 1,
    2 => 100,
    3 => 1000,
    _ => throw StateError('Unsupported exponent $exponent for $code'),
  };

  /// Returns the currency for [code], or null when it is not supported.
  static Currency? tryParse(String code) {
    for (final currency in Currency.values) {
      if (currency.code == code) return currency;
    }
    return null;
  }
}
