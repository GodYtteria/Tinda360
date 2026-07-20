import 'package:tinda360/core/calendar/local_day.dart';

/// An inclusive range of local days, e.g. today, or the last 7 days.
final class DayRange {
  /// Creates the range from [first] to [last], both inclusive.
  const DayRange(this.first, this.last);

  /// A range covering only [day].
  const DayRange.single(LocalDay day) : first = day, last = day;

  /// The first day in the range.
  final LocalDay first;

  /// The last day in the range.
  final LocalDay last;

  @override
  bool operator ==(Object other) =>
      other is DayRange && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);
}
