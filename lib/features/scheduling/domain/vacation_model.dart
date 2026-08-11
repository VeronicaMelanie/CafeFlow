import 'package:cloud_firestore/cloud_firestore.dart';

class VacationModel {
  final String id;
  final String userId;
  final String userName;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'pending', 'approved', 'rejected'
  final String? adminComment;
  final DateTime requestedAt;

  VacationModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.adminComment,
    required this.requestedAt,
  });

  int get durationInDays {
    return endDate.difference(startDate).inDays + 1;
  }

  factory VacationModel.fromMap(Map<String, dynamic> map, String id) {
    try {
      return VacationModel(
        id: id,
        userId: map['userId']?.toString() ?? '',
        userName: map['userName']?.toString() ?? '',
        startDate: map['startDate'] is Timestamp 
            ? (map['startDate'] as Timestamp).toDate() 
            : DateTime.now(),
        endDate: map['endDate'] is Timestamp 
            ? (map['endDate'] as Timestamp).toDate() 
            : DateTime.now().add(const Duration(days: 1)),
        status: map['status']?.toString() ?? 'pending',
        adminComment: map['adminComment']?.toString(),
        requestedAt: map['requestedAt'] is Timestamp 
            ? (map['requestedAt'] as Timestamp).toDate() 
            : DateTime.now(),
      );
    } catch (e) {
      throw FormatException('Eroare la parsarea VacationModel (id: $id). Detalii: $e');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status,
      'adminComment': adminComment,
      'requestedAt': Timestamp.fromDate(requestedAt),
    };
  }
}
