/// An amount of a product in thousandths of its unit.
///
/// One piece is 1000; a quarter kilo is 250. Stored as an integer so stock
/// arithmetic is exact.
final class Quantity implements Comparable<Quantity> {
  /// Creates a quantity of [milli] thousandths of a unit.
  const Quantity.milli(this.milli);

  /// Creates a quantity of [count] whole units.
  const Quantity.whole(int count) : milli = count * milliPerUnit;

  /// Thousandths per whole unit.
  static const int milliPerUnit = 1000;

  /// Zero units.
  static const Quantity zero = Quantity.milli(0);

  /// The amount in thousandths of a unit.
  final int milli;

  /// Whether this is a whole number of units.
  bool get isWhole => milli % milliPerUnit == 0;

  /// Whether this is more than zero.
  bool get isPositive => milli > 0;

  /// Whether this is below zero.
  bool get isNegative => milli < 0;

  /// The sum of this and [other].
  Quantity operator +(Quantity other) => Quantity.milli(milli + other.milli);

  /// This minus [other].
  Quantity operator -(Quantity other) => Quantity.milli(milli - other.milli);

  /// This quantity with the sign flipped.
  Quantity operator -() => Quantity.milli(-milli);

  @override
  int compareTo(Quantity other) => milli.compareTo(other.milli);

  @override
  bool operator ==(Object other) => other is Quantity && other.milli == milli;

  @override
  int get hashCode => milli.hashCode;

  @override
  String toString() => 'Quantity($milli milli)';
}
