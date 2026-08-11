/// Business rules for which months employees may edit availability.
class SchedulingMonthUtils {
  static const int shopOpenHour = 7;
  static const int shopCloseHour = 18;
  static const double fullShiftHours = 11.0;

  /// First day of [month] at midnight (local).
  static DateTime monthStart(DateTime month) =>
      DateTime(month.year, month.month, 1);

  /// Last day of [month] at 23:59:59 (local).
  static DateTime monthEnd(DateTime month) =>
      DateTime(month.year, month.month + 1, 0, 23, 59, 59);

  /// Calendar date without time (local midnight).
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// True when [date] falls inside the calendar month of [month].
  static bool isDateInMonth(DateTime date, DateTime month) =>
      date.year == month.year && date.month == month.month;

  /// Inclusive vacation days overlapping [month] (date-only comparison).
  static int vacationDaysInMonth(
    DateTime vacationStart,
    DateTime vacationEnd,
    DateTime month,
  ) {
    final monthFirst = dateOnly(monthStart(month));
    final monthLast = dateOnly(monthEnd(month));
    final rangeStart = dateOnly(vacationStart);
    final rangeEnd = dateOnly(vacationEnd);

    final overlapStart =
        rangeStart.isAfter(monthFirst) ? rangeStart : monthFirst;
    final overlapEnd = rangeEnd.isBefore(monthLast) ? rangeEnd : monthLast;

    if (overlapStart.isAfter(overlapEnd)) return 0;
    return overlapEnd.difference(overlapStart).inDays + 1;
  }

  /// True when employees may still add/remove/edit availability for [scheduleMonth].
  ///
  /// Locked from the first calendar day of that month onward.
  static bool isMonthEditable(DateTime scheduleMonth, [DateTime? now]) {
    final today = now ?? DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final monthFirst = monthStart(scheduleMonth);
    return monthFirst.isAfter(todayDate);
  }

  /// Document id for global (all locations) scheduling config.
  static String globalConfigDocId(int year, int month) =>
      '${year}_${month.toString().padLeft(2, '0')}';

  /// Document id for location-specific scheduling config.
  static String locationConfigDocId(int year, int month, String location) =>
      '${globalConfigDocId(year, month)}_$location';
}
