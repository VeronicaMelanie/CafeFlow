import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/vacation_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VacationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<VacationModel>> getVacationsForUser(String userId) {
    return _firestore
        .collection('vacations')
        .where('userId', isEqualTo: userId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VacationModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<VacationModel>> getAllPendingVacations() {
    return _firestore
        .collection('vacations')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VacationModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> requestVacation(VacationModel vacation) async {
    await _firestore.collection('vacations').add(vacation.toMap());
  }

  Future<void> updateVacationStatus(String vacationId, String status, {String? comment}) async {
    await _firestore.collection('vacations').doc(vacationId).update({
      'status': status,
      'adminComment': comment,
    });
  }
}

final vacationRepositoryProvider = Provider((ref) => VacationRepository());
