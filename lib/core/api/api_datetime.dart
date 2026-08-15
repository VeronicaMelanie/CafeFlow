/// Deterministic parsers for PostgreSQL DATE / TIME / TIMESTAMPTZ JSON.
class ApiDateTime {
  ApiDateTime._();

  /// `YYYY-MM-DD` → local calendar date at midnight. Not UTC.
  static DateTime parseDateOnly(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid DATE: $value');
    }
    return DateTime(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
  }

  /// Local calendar date → `YYYY-MM-DD`. Uses year/month/day, not UTC.
  static String formatDateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Local wall-clock time → `HH:MM:SS`. Does not convert to UTC.
  static String formatTimeOnly(DateTime time) {
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    final seconds = time.second.toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// `HH:MM:SS` on [date] as a local DateTime (wall clock, not UTC).
  static DateTime? combineDateAndTime(DateTime date, String? time) {
    if (time == null || time.isEmpty) return null;
    final match = RegExp(r'^(\d{2}):(\d{2})(?::(\d{2}))?').firstMatch(time);
    if (match == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3] ?? '0'),
    );
  }

  /// ISO-8601 timestamptz → local DateTime.
  static DateTime parseTimestamptz(String value) {
    return DateTime.parse(value).toLocal();
  }

  /// Local DateTime → UTC ISO-8601 for PostgreSQL TIMESTAMPTZ.
  /// Wall-clock is preserved on read via [parseTimestamptz].
  static String formatTimestamptz(DateTime value) {
    return value.toUtc().toIso8601String();
  }
}
