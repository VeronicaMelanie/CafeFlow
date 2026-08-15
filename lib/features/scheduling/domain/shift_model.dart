import '../../../core/api/api_datetime.dart';

class ShiftModel {
  final String id;
  final String userId;
  final String userName;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final String type; // 'FULL', 'CUSTOM', 'VACATION'
  final String location; // 'Gara', 'Avantgarden'
  final String status; // 'pending', 'approved', 'auto-assigned'

  ShiftModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.location,
    required this.status,
  });

  double get durationInHours {
    return endTime.difference(startTime).inMinutes / 60.0;
  }

  /// Maps GET /api/shifts JSON.
  /// [firebaseUid] is the Firebase UID for API `user_id`.
  /// [locationName] is LocationModel.name for API `location_id`.
  /// [userName] is derived from UserModel; empty when unknown — never invented.
  factory ShiftModel.fromApiJson(
    Map<String, dynamic> json, {
    required String firebaseUid,
    required String locationName,
    required String userName,
  }) {
    final workDate = ApiDateTime.parseDateOnly(
      json['work_date']?.toString() ?? '',
    );
    return ShiftModel(
      id: json['id']?.toString() ?? '',
      userId: firebaseUid,
      userName: userName,
      date: workDate,
      startTime: ApiDateTime.parseTimestamptz(json['start_at']?.toString() ?? ''),
      endTime: ApiDateTime.parseTimestamptz(json['end_at']?.toString() ?? ''),
      type: json['type']?.toString() ?? 'FULL',
      location: locationName,
      status: json['status']?.toString() ?? 'pending',
    );
  }
}
