/// ISO week identifiers for weekly completion reset.
class CleaningWeekUtils {
  CleaningWeekUtils._();

  static String weekIdFor(DateTime date) {
    final (year, week) = isoWeekYear(date);
    return '$year-W${week.toString().padLeft(2, '0')}';
  }

  static (int year, int week) isoWeekYear(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    final thursday = local.add(Duration(days: 4 - local.weekday));
    final year = thursday.year;
    final firstThursday = DateTime(year, 1, 4)
        .add(Duration(days: 4 - DateTime(year, 1, 4).weekday));
    final week = 1 + thursday.difference(firstThursday).inDays ~/ 7;
    return (year, week);
  }
}
