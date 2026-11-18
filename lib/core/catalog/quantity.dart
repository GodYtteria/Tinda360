final class Quantity implements Comparable<Quantity> {
  const Quantity.milli(this.milli);

  const Quantity.whole(int count) : milli = count * milliPerUnit;

  static const int milliPerUnit = 1000;

  static const Quantity zero = Quantity.milli(0);

  final int milli;

  bool get isWhole => milli % milliPerUnit == 0;

  bool get isPositive => milli > 0;

  bool get isNegative => milli < 0;

  Quantity operator +(Quantity other) => Quantity.milli(milli + other.milli);

  Quantity operator -(Quantity other) => Quantity.milli(milli - other.milli);

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
