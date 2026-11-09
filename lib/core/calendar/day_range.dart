import 'package:meta/meta.dart';
import 'package:tinda360/core/calendar/local_day.dart';

@immutable
final class DayRange {
  const new(this.first, this.last);

  const new single(LocalDay day) : first = day, last = day;

  final LocalDay first;

  final LocalDay last;

  @override
  bool operator ==(Object other) =>
      other is DayRange && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);
}
