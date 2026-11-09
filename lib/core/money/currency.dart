enum Currency {
  php('PHP', 2);

  new(this.code, this.exponent);

  final String code;

  final int exponent;

  int get minorPerMajor => switch (exponent) {
    0 => 1,
    2 => 100,
    3 => 1000,
    _ => throw StateError('Unsupported exponent $exponent for $code'),
  };

  static Currency? tryParse(String code) {
    for (final currency in Currency.values) {
      if (currency.code == code) return currency;
    }
    return null;
  }
}
