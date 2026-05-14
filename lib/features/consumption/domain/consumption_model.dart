import 'package:cloud_firestore/cloud_firestore.dart';

class ConsumptionModel {
  final String id;
  final String userId;
  final String productName;
  final int quantity;
  final DateTime date;

  ConsumptionModel({
    required this.id,
    required this.userId,
    required this.productName,
    required this.quantity,
    required this.date,
  });

  factory ConsumptionModel.fromMap(Map<String, dynamic> map, String id) {
    return ConsumptionModel(
      id: id,
      userId: map['userId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 0,
      date: (map['date'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'productName': productName,
      'quantity': quantity,
      'date': Timestamp.fromDate(date),
    };
  }
}
