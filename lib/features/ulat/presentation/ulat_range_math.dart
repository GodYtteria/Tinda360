import 'package:tinda360/core/calendar/day_range.dart';
import 'package:tinda360/core/calendar/local_day.dart';

const int maxCustomRangeDays = 366;

DateTime dateOfLocalDay(LocalDay day) => day.toLocalDate();

DayRange thisMonthRange(LocalDay today) {
  final todayDate = dateOfLocalDay(today);
  return DayRange(
    LocalDay.fromLocal(DateTime(todayDate.year, todayDate.month)),
    today,
  );
}

DayRange lastMonthRange(LocalDay today) {
  final todayDate = dateOfLocalDay(today);
  final firstOfLastMonth = LocalDay.fromLocal(
    DateTime(todayDate.year, todayDate.month - 1),
  );
  final firstOfThisMonth = LocalDay.fromLocal(
    DateTime(todayDate.year, todayDate.month),
  );
  return DayRange(firstOfLastMonth, firstOfThisMonth.plusDays(-1));
}

int dayCountOf(DayRange range) => range.last.serial - range.first.serial + 1;

bool isValidCustomRange(DayRange range, LocalDay today) =>
    range.first.serial <= range.last.serial &&
    range.last.serial <= today.serial &&
    dayCountOf(range) <= maxCustomRangeDays;

DayRange? customRangeFromPicker({
  required DateTime start,
  required DateTime end,
  required LocalDay today,
}) {
  final range = DayRange(LocalDay.fromLocal(start), LocalDay.fromLocal(end));
  return isValidCustomRange(range, today) ? range : null;
}
