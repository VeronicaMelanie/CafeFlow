import '../../../core/l10n/l10n.dart';

/// Employee availability shift type for a single day.
enum AvailabilityShiftType {
  fullTime('full_time'),
  customHours('custom_hours');

  const AvailabilityShiftType(this.firestoreValue);
  final String firestoreValue;

  static AvailabilityShiftType fromFirestore(String? value, {bool? legacyIsFullDay}) {
    if (value == 'full_time') return AvailabilityShiftType.fullTime;
    if (value == 'custom_hours') return AvailabilityShiftType.customHours;
    // Legacy values.
    if (value == 'part_time') return AvailabilityShiftType.customHours;
    if (legacyIsFullDay == false) return AvailabilityShiftType.customHours;
    return AvailabilityShiftType.fullTime;
  }

  String get displayLabel => labelFor(L10n.fallback);

  String labelFor(L10n l10n) => this == AvailabilityShiftType.fullTime
      ? l10n.pick('All day', 'Toată ziua')
      : l10n.pick('Custom hours', 'Ore personalizate');
}
