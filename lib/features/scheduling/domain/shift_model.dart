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
    try {
      return ShiftModel(
        id: id,
        userId: map['userId']?.toString() ?? '',
        userName: map['userName']?.toString() ?? '',
        date: map['date'] is Timestamp 
            ? (map['date'] as Timestamp).toDate() 
            : DateTime.now(),
        startTime: map['startTime'] is Timestamp 
            ? (map['startTime'] as Timestamp).toDate() 
            : DateTime.now(),
        endTime: map['endTime'] is Timestamp 
            ? (map['endTime'] as Timestamp).toDate() 
            : DateTime.now().add(const Duration(hours: 8)),
        type: map['type']?.toString() ?? 'FULL',
        location: map['location']?.toString() ?? 'Gara',
        status: map['status']?.toString() ?? 'pending',
      );
    } catch (e) {
      throw FormatException('Eroare la parsarea ShiftModel (id: $id). Detalii: $e');
    }
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
