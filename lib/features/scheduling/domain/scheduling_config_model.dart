import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin-controlled gate for employee availability submission per month.
class SchedulingConfigModel {
  final String id;
  final int year;
  final int month;
  final String? location;
  final bool schedulingEnabled;
  final bool lockedMonth;
  final DateTime? enabledAt;
  final String? enabledBy;
  final double maxHoursPerDay;
  final int maxEmployeesPerShift;

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

  factory SchedulingConfigModel.fromMap(Map<String, dynamic> map, String id) {
    return SchedulingConfigModel(
      id: id,
      year: (map['year'] as num?)?.toInt() ?? 0,
      month: (map['month'] as num?)?.toInt() ?? 0,
      location: map['location'] as String?,
      schedulingEnabled: map['schedulingEnabled'] as bool? ?? false,
      lockedMonth: map['lockedMonth'] as bool? ?? false,
      enabledAt: map['enabledAt'] != null
          ? (map['enabledAt'] as Timestamp).toDate()
          : null,
      enabledBy: map['enabledBy'] as String?,
      maxHoursPerDay: (map['maxHoursPerDay'] as num?)?.toDouble() ?? 22.0,
      maxEmployeesPerShift: (map['maxEmployeesPerShift'] as num?)?.toInt() ?? 2,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'year': year,
      'month': month,
      if (location != null && location!.isNotEmpty) 'location': location,
      'schedulingEnabled': schedulingEnabled,
      'lockedMonth': lockedMonth,
      if (enabledAt != null) 'enabledAt': Timestamp.fromDate(enabledAt!),
      if (enabledBy != null) 'enabledBy': enabledBy,
      'maxHoursPerDay': maxHoursPerDay,
      'maxEmployeesPerShift': maxEmployeesPerShift,
    };
  }
}
