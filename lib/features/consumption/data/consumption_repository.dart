import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/consumption_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConsumptionRepository {
  ConsumptionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @visibleForTesting
  ConsumptionRepository.test() : _firestore = null;

  final FirebaseFirestore? _firestore;

  Stream<List<ConsumptionModel>> getUserConsumptions(
    String userId,
    DateTime month,
  ) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    return _firestore!
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

    return _firestore!
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

  Stream<List<ConsumptionModel>> getConsumptionsForUser(String userId) {
    return _firestore!
        .collection('consumptions')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ConsumptionModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  Future<void> addConsumption(ConsumptionModel consumption) async {
    await _firestore!.collection('consumptions').add(consumption.toMap());
  }

  Future<void> updateConsumption(
    String id,
    String productName,
    int quantity,
    String notes,
  ) async {
    await _firestore!.collection('consumptions').doc(id).update({
      'productName': productName,
      'quantity': quantity,
      'notes': notes,
    });
  }

  Future<void> deleteConsumption(String id) async {
    await _firestore!.collection('consumptions').doc(id).delete();
  }
}

final consumptionRepositoryProvider = Provider(
  (ref) => ConsumptionRepository(),
);
