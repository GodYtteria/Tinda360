import 'package:tinda360/core/calendar/local_day.dart';

sealed class ExpiryStatus {
  const new();
}

final class ExpiryExpired extends ExpiryStatus {
  const new();
}

final class ExpiryNear extends ExpiryStatus {
  const new(this.daysLeft);

  final int daysLeft;
}

abstract final class ExpiryRules {
  static const int nearDays = 14;

  static ExpiryStatus? statusFor(LocalDay? expiryDay, LocalDay today) {
    if (expiryDay == null) return null;
    final daysLeft = expiryDay.serial - today.serial;
    if (daysLeft < 0) return const ExpiryExpired();
    if (daysLeft <= nearDays) return ExpiryNear(daysLeft);
    return null;
  }

  static String formatIso(LocalDay day) {
    final date = day.toLocalDate();
    final month = date.month.toString().padLeft(2, '0');
    final dayOfMonth = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$dayOfMonth';
  }

  static LocalDay? parseIso(String text) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text.trim());
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final dayOfMonth = int.parse(match.group(3)!);
    final date = DateTime(year, month, dayOfMonth);
    if (date.year != year || date.month != month || date.day != dayOfMonth) {
      return null;
    }
    return LocalDay.fromLocal(date);
  }
}
