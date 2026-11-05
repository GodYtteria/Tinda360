enum ProductUnit {
  piece('piece', allowsFraction: false),

  pack('pack', allowsFraction: false),

  sachet('sachet', allowsFraction: false),

  can('can', allowsFraction: false),

  bottle('bottle', allowsFraction: false),

  bar('bar', allowsFraction: false),

  bag('bag', allowsFraction: false),

  kilo('kilo', allowsFraction: true),

  liter('liter', allowsFraction: true);

  const ProductUnit(this.storageName, {required this.allowsFraction});

  final String storageName;

  final bool allowsFraction;

  static ProductUnit? tryParse(String storageName) {
    for (final unit in ProductUnit.values) {
      if (unit.storageName == storageName) return unit;
    }
    return null;
  }
}
