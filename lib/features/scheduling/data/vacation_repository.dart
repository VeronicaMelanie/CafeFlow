import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/vacation_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VacationRepository {
  VacationRepository({FirebaseFirestore? firestore, bool testMode = false})
      : _firestore = testMode ? null : (firestore ?? FirebaseFirestore.instance),
        _testMode = testMode;

  @visibleForTesting
  VacationRepository.test() : this(testMode: true);

  final FirebaseFirestore? _firestore;
  final bool _testMode;

  Stream<List<VacationModel>> getVacationsForUser(String userId) {
    if (_testMode) return Stream.value(const []);
    return _firestore!
        .collection('vacations')
        .where('userId', isEqualTo: userId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VacationModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<VacationModel>> getAllPendingVacations() {
    if (_testMode) return Stream.value(const []);
    return _firestore!
        .collection('vacations')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VacationModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> requestVacation(VacationModel vacation) async {
    if (_testMode) return;
    await _firestore!.collection('vacations').add(vacation.toMap());
  }

  Future<void> updateVacationStatus(String vacationId, String status, {String? comment}) async {
    if (_testMode) return;
    await _firestore!.collection('vacations').doc(vacationId).update({
      'status': status,
      'adminComment': comment,
    });
  }
}

final vacationRepositoryProvider = Provider((ref) => VacationRepository());
