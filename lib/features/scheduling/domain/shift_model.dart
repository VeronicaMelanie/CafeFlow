import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory ShiftModel.fromMap(Map<String, dynamic> map, String id) {
    return ShiftModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      type: map['type'] ?? 'FULL',
      location: map['location'] ?? 'Gara',
      status: map['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'date': Timestamp.fromDate(date),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'type': type,
      'location': location,
      'status': status,
    };
  }
}
