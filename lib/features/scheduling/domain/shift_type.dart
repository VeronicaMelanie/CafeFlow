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

  String get displayLabel =>
      this == AvailabilityShiftType.fullTime ? 'Full Time' : 'Custom hours';
}
