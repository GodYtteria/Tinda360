/// How a product is counted and sold.
///
/// [storageName] is what the database stores; the `products.unit` CHECK
/// constraint lists exactly these values.
enum ProductUnit {
  /// Per piece.
  piece('piece', allowsFraction: false),

  /// Per pack.
  pack('pack', allowsFraction: false),

  /// Per sachet.
  sachet('sachet', allowsFraction: false),

  /// Per can.
  can('can', allowsFraction: false),

  /// Per bottle.
  bottle('bottle', allowsFraction: false),

  /// Per bar (e.g. laundry soap).
  bar('bar', allowsFraction: false),

  /// Per bag (supot).
  bag('bag', allowsFraction: false),

  /// Per kilogram; can be sold in parts, e.g. ¼ kilo.
  kilo('kilo', allowsFraction: true),

  /// Per liter; can be sold in parts.
  liter('liter', allowsFraction: true);

  const ProductUnit(this.storageName, {required this.allowsFraction});

  /// The value stored in the database.
  final String storageName;

  /// Whether a quantity that is not a whole number is valid for this unit.
  final bool allowsFraction;

  /// Returns the unit stored as [storageName], or null if none matches.
  static ProductUnit? tryParse(String storageName) {
    for (final unit in ProductUnit.values) {
      if (unit.storageName == storageName) return unit;
    }
    return null;
  }
}
