import 'package:tinda360/core/calendar/local_day.dart';

final class DayRange {
  const DayRange(this.first, this.last);

  const DayRange.single(LocalDay day) : first = day, last = day;

  final LocalDay first;

  final LocalDay last;

  @override
  bool operator ==(Object other) =>
      other is DayRange && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);
}
