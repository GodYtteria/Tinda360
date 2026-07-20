/// A calendar day in the store's local time, stored as a serial integer.
///
/// Never an instant: a sale at 11:30 PM local time belongs to that local day
/// regardless of the UTC offset.
final class LocalDay implements Comparable<LocalDay> {
  /// Creates the day with the given [serial] (days since 1970-01-01).
  const LocalDay(this.serial);

  /// The local calendar day containing [local], a local-time [DateTime].
  factory LocalDay.fromLocal(DateTime local) => LocalDay(
    DateTime.utc(local.year, local.month, local.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay,
  );

  /// Days since 1970-01-01 in local calendar terms.
  final int serial;

  /// The day [days] after this one (negative goes back).
  LocalDay plusDays(int days) => LocalDay(serial + days);

  @override
  int compareTo(LocalDay other) => serial.compareTo(other.serial);

  @override
  bool operator ==(Object other) => other is LocalDay && other.serial == serial;

  @override
  int get hashCode => serial.hashCode;

  @override
  String toString() => 'LocalDay($serial)';
}
