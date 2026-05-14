import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/consumption_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConsumptionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ConsumptionModel>> getUserConsumptions(String userId, DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    return _firestore
        .collection('consumptions')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ConsumptionModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<ConsumptionModel>> getAllConsumptions(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    return _firestore
        .collection('consumptions')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ConsumptionModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> addConsumption(ConsumptionModel consumption) async {
    await _firestore.collection('consumptions').add(consumption.toMap());
  }
}

final consumptionRepositoryProvider = Provider((ref) => ConsumptionRepository());

