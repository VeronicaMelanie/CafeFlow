import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/pwa/schedule_offline_cache.dart';
import '../domain/shift_model.dart';

class ShiftRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ShiftModel>> getShiftsForMonth(DateTime month, String location) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    return _firestore
        .collection('shifts')
        .where('location', isEqualTo: location)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ShiftModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<ShiftModel>> getUserShiftsForMonth(String userId, DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    return _firestore
        .collection('shifts')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .asyncMap((snapshot) async {
      final shifts = snapshot.docs
          .map((doc) => ShiftModel.fromMap(doc.data(), doc.id))
          .toList();
      if (kIsWeb) {
        await ScheduleOfflineCache().saveShifts(userId, shifts);
      }
      return shifts;
    });
  }

  /// Last locally cached shifts (web offline fallback).
  Future<List<ShiftModel>> getCachedUserShifts(String userId) {
    return ScheduleOfflineCache().loadShifts(userId);
  }

  Future<void> deleteShift(String shiftId) async {
    await _firestore.collection('shifts').doc(shiftId).delete();
  }

  Future<List<ShiftModel>> getEmployeeShifts(String userId) async {
    final snap = await _firestore
        .collection('shifts')
        .where('userId', isEqualTo: userId)
        .get();
    return snap.docs.map((doc) => ShiftModel.fromMap(doc.data(), doc.id)).toList();
  }
}

