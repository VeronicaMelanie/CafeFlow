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
    return VacationModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      status: map['status'] ?? 'pending',
      adminComment: map['adminComment'],
      requestedAt: (map['requestedAt'] as Timestamp).toDate(),
    );
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
