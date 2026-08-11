import 'package:cloud_firestore/cloud_firestore.dart';
import 'shift_type.dart';
import '../utils/scheduling_month_utils.dart';

class AvailabilityModel {
  final String id;
  final String userId;
  final DateTime date;
  final AvailabilityShiftType shiftType;
  final DateTime? customStartTime;
  final DateTime? customEndTime;
  final DateTime? submissionTimestamp;

  /// Legacy field — kept for backward compatibility when reading old docs.
  final bool isFullDay;

  AvailabilityModel({
    required this.id,
    required this.userId,
    required this.date,
    this.shiftType = AvailabilityShiftType.fullTime,
    this.customStartTime,
    this.customEndTime,
    this.submissionTimestamp,
    bool? isFullDay,
  }) : isFullDay = isFullDay ?? (shiftType == AvailabilityShiftType.fullTime);

  factory AvailabilityModel.fromMap(Map<String, dynamic> map, String id) {
    try {
      final legacyFull = map['isFullDay'] is bool ? map['isFullDay'] as bool : true;
      final shiftType = AvailabilityShiftType.fromFirestore(
        map['shiftType']?.toString(),
        legacyIsFullDay: legacyFull,
      );

      return AvailabilityModel(
        id: id,
        userId: map['userId']?.toString() ?? '',
        date: map['date'] is Timestamp 
            ? (map['date'] as Timestamp).toDate() 
            : DateTime.now(),
        shiftType: shiftType,
        customStartTime: map['customStartTime'] is Timestamp 
            ? (map['customStartTime'] as Timestamp).toDate() 
            : null,
        customEndTime: map['customEndTime'] is Timestamp 
            ? (map['customEndTime'] as Timestamp).toDate() 
            : null,
        submissionTimestamp: map['submissionTimestamp'] is Timestamp 
            ? (map['submissionTimestamp'] as Timestamp).toDate() 
            : null,
        isFullDay: legacyFull,
      );
    } catch (e) {
      throw FormatException('Eroare la parsarea AvailabilityModel (id: $id). Detalii: $e');
    }
  }

  Map<String, dynamic> toMap({bool useServerTimestamp = false}) {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'shiftType': shiftType.firestoreValue,
      'isFullDay': shiftType == AvailabilityShiftType.fullTime,
      'customStartTime': _startTime != null
          ? Timestamp.fromDate(_startTime!)
          : null,
      'customEndTime':
          _endTime != null ? Timestamp.fromDate(_endTime!) : null,
      'submissionTimestamp': useServerTimestamp
          ? FieldValue.serverTimestamp()
          : (submissionTimestamp != null
              ? Timestamp.fromDate(submissionTimestamp!)
              : FieldValue.serverTimestamp()),
    };
  }

  DateTime? get _startTime {
    if (shiftType == AvailabilityShiftType.fullTime) {
      return DateTime(
        date.year,
        date.month,
        date.day,
        SchedulingMonthUtils.shopOpenHour,
      );
    }
    return customStartTime;
  }

  DateTime? get _endTime {
    if (shiftType == AvailabilityShiftType.fullTime) {
      return DateTime(
        date.year,
        date.month,
        date.day,
        SchedulingMonthUtils.shopCloseHour,
      );
    }
    return customEndTime;
  }

  DateTime get effectiveStartTime => _startTime!;
  DateTime get effectiveEndTime => _endTime!;

  double get durationInHours {
    if (shiftType == AvailabilityShiftType.fullTime) {
      return SchedulingMonthUtils.fullShiftHours;
    }
    if (customStartTime != null && customEndTime != null) {
      return customEndTime!.difference(customStartTime!).inMinutes / 60.0;
    }
    return 0.0;
  }

  /// Sort key for first-come-first-served scheduling (older = higher priority).
  DateTime get fcfsSortKey =>
      submissionTimestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
}
