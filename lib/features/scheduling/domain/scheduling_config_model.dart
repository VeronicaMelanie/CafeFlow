import '../../../core/api/api_datetime.dart';

/// Admin-controlled gate for employee availability submission per month.
class SchedulingConfigModel {
  final String id;
  final int year;
  final int month;
  final String? location;
  final bool schedulingEnabled;
  final bool lockedMonth;
  final DateTime? enabledAt;
  /// Firebase UID when mapped from API `enabled_by` UUID.
  final String? enabledBy;
  /// Null when the API omits a limit. Do not treat null as 22.
  final double? maxHoursPerDay;
  /// Null when the API omits a limit. Do not treat null as 2.
  final int? maxEmployeesPerShift;

  const SchedulingConfigModel({
    required this.id,
    required this.year,
    required this.month,
    this.location,
    this.schedulingEnabled = false,
    this.lockedMonth = false,
    this.enabledAt,
    this.enabledBy,
    this.maxHoursPerDay = 22.0,
    this.maxEmployeesPerShift = 2,
  });

  DateTime get monthDate => DateTime(year, month, 1);

  bool get isGlobal => location == null || location!.isEmpty;

  /// Maps GET /api/scheduling JSON.
  /// [locationName] is LocationModel.name for [location_id], or null if global.
  /// [enabledByFirebaseUid] is the Firebase UID for [enabled_by], or null.
  factory SchedulingConfigModel.fromApiJson(
    Map<String, dynamic> json, {
    String? locationName,
    String? enabledByFirebaseUid,
  }) {
    final enabledAt = json['enabled_at']?.toString();
    return SchedulingConfigModel(
      id: json['id']?.toString() ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      month: (json['month'] as num?)?.toInt() ?? 0,
      location: locationName,
      schedulingEnabled: json['scheduling_enabled'] == true,
      lockedMonth: json['locked_month'] == true,
      enabledAt: enabledAt == null || enabledAt.isEmpty
          ? null
          : ApiDateTime.parseTimestamptz(enabledAt),
      enabledBy: enabledByFirebaseUid,
      maxHoursPerDay: (json['max_hours_per_day'] as num?)?.toDouble(),
      maxEmployeesPerShift: (json['max_employees_per_shift'] as num?)?.toInt(),
    );
  }
}
