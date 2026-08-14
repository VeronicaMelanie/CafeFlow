/// Permanent cleaning list keys. [closing] is shared across all days.
enum CleaningListKey {
  closing,
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday;

  static const ordered = CleaningListKey.values;

  String get label {
    switch (this) {
      case CleaningListKey.closing:
        return 'Closing';
      case CleaningListKey.monday:
        return 'Monday';
      case CleaningListKey.tuesday:
        return 'Tuesday';
      case CleaningListKey.wednesday:
        return 'Wednesday';
      case CleaningListKey.thursday:
        return 'Thursday';
      case CleaningListKey.friday:
        return 'Friday';
      case CleaningListKey.saturday:
        return 'Saturday';
      case CleaningListKey.sunday:
        return 'Sunday';
    }
  }

  String get shortLabel {
    switch (this) {
      case CleaningListKey.closing:
        return 'Closing';
      case CleaningListKey.monday:
        return 'Mon';
      case CleaningListKey.tuesday:
        return 'Tue';
      case CleaningListKey.wednesday:
        return 'Wed';
      case CleaningListKey.thursday:
        return 'Thu';
      case CleaningListKey.friday:
        return 'Fri';
      case CleaningListKey.saturday:
        return 'Sat';
      case CleaningListKey.sunday:
        return 'Sun';
    }
  }

  static CleaningListKey fromStorage(String value) {
    return CleaningListKey.values.firstWhere(
      (key) => key.name == value,
      orElse: () => CleaningListKey.closing,
    );
  }

  static String listId(String location, CleaningListKey key) =>
      '${location}_${key.name}';
}
