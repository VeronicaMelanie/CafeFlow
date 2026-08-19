import '../../../core/l10n/l10n.dart';

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

  String get label => labelFor(L10n.fallback);

  String get shortLabel => shortLabelFor(L10n.fallback);

  String labelFor(L10n l10n) {
    switch (this) {
      case CleaningListKey.closing:
        return l10n.pick('Closing', 'Închidere');
      case CleaningListKey.monday:
        return l10n.pick('Monday', 'Luni');
      case CleaningListKey.tuesday:
        return l10n.pick('Tuesday', 'Marți');
      case CleaningListKey.wednesday:
        return l10n.pick('Wednesday', 'Miercuri');
      case CleaningListKey.thursday:
        return l10n.pick('Thursday', 'Joi');
      case CleaningListKey.friday:
        return l10n.pick('Friday', 'Vineri');
      case CleaningListKey.saturday:
        return l10n.pick('Saturday', 'Sâmbătă');
      case CleaningListKey.sunday:
        return l10n.pick('Sunday', 'Duminică');
    }
  }

  String shortLabelFor(L10n l10n) {
    switch (this) {
      case CleaningListKey.closing:
        return l10n.pick('Cls.', 'Înch.');
      case CleaningListKey.monday:
        return l10n.pick('Mon', 'Lu');
      case CleaningListKey.tuesday:
        return l10n.pick('Tue', 'Ma');
      case CleaningListKey.wednesday:
        return l10n.pick('Wed', 'Mi');
      case CleaningListKey.thursday:
        return l10n.pick('Thu', 'Jo');
      case CleaningListKey.friday:
        return l10n.pick('Fri', 'Vi');
      case CleaningListKey.saturday:
        return l10n.pick('Sat', 'Sâ');
      case CleaningListKey.sunday:
        return l10n.pick('Sun', 'Du');
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
