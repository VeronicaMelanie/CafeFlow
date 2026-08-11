import 'package:cloud_firestore/cloud_firestore.dart';

class ConsumptionModel {
  final String id;
  final String userId;
  final String productName;
  final int quantity;
  final DateTime date;
  final String? notes;

  ConsumptionModel({
    required this.id,
    required this.userId,
    required this.productName,
    required this.quantity,
    required this.date,
    this.notes,
  });

  factory ConsumptionModel.fromMap(Map<String, dynamic> map, String id) {
    try {
      return ConsumptionModel(
        id: id,
        userId: map['userId']?.toString() ?? '',
        productName: map['productName']?.toString() ?? '',
        quantity: (map['quantity'] as num?)?.toInt() ?? 0,
        date: map['date'] is Timestamp 
            ? (map['date'] as Timestamp).toDate() 
            : DateTime.now(),
        notes: map['notes']?.toString(),
      );
    } catch (e) {
      throw FormatException('Eroare la parsarea ConsumptionModel (id: $id). Detalii: $e');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'productName': productName,
      'quantity': quantity,
      'date': Timestamp.fromDate(date),
      if (notes != null) 'notes': notes,
    };
  }
}
