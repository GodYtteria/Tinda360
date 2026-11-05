final class LocalDay implements Comparable<LocalDay> {
  const LocalDay(this.serial);

  factory LocalDay.fromLocal(DateTime local) => LocalDay(
    DateTime.utc(local.year, local.month, local.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay,
  );

  final int serial;

  LocalDay plusDays(int days) => LocalDay(serial + days);

  DateTime toLocalDate() {
    final utcDate = DateTime.fromMillisecondsSinceEpoch(
      serial * Duration.millisecondsPerDay,
      isUtc: true,
    );
    return DateTime(utcDate.year, utcDate.month, utcDate.day);
  }

  @override
  int compareTo(LocalDay other) => serial.compareTo(other.serial);

  @override
  bool operator ==(Object other) => other is LocalDay && other.serial == serial;

  @override
  int get hashCode => serial.hashCode;

  @override
  String toString() => 'LocalDay($serial)';
}
