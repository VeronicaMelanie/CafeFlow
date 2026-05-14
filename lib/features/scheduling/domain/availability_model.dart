import 'package:cloud_firestore/cloud_firestore.dart';

class AvailabilityModel {
  final String id;
  final String userId;
  final DateTime date;
  final bool isFullDay; // true for 07:00-18:00
  final DateTime? customStartTime;
  final DateTime? customEndTime;

  AvailabilityModel({
    required this.id,
    required this.userId,
    required this.date,
    this.isFullDay = true,
    this.customStartTime,
    this.customEndTime,
  });

  factory AvailabilityModel.fromMap(Map<String, dynamic> map, String id) {
    return AvailabilityModel(
      id: id,
      userId: map['userId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      isFullDay: map['isFullDay'] ?? true,
      customStartTime: map['customStartTime'] != null ? (map['customStartTime'] as Timestamp).toDate() : null,
      customEndTime: map['customEndTime'] != null ? (map['customEndTime'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'isFullDay': isFullDay,
      'customStartTime': customStartTime != null ? Timestamp.fromDate(customStartTime!) : null,
      'customEndTime': customEndTime != null ? Timestamp.fromDate(customEndTime!) : null,
    };
  }

  double get durationInHours {
    if (isFullDay) return 11.0;
    if (customStartTime != null && customEndTime != null) {
      return customEndTime!.difference(customStartTime!).inMinutes / 60.0;
    }
    return 0.0;
  }
}
