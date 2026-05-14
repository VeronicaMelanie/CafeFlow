import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/shift_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ShiftModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }


  Future<String?> bookShift(ShiftModel shift) async {
    // 1. Check for user overlap
    final userOverlaps = await _firestore
        .collection('shifts')
        .where('userId', isEqualTo: shift.userId)
        .where('date', isEqualTo: Timestamp.fromDate(shift.date))
        .get();

    for (var doc in userOverlaps.docs) {
      final existingShift = ShiftModel.fromMap(doc.data(), doc.id);
      if (shift.startTime.isBefore(existingShift.endTime) &&
          shift.endTime.isAfter(existingShift.startTime)) {
        return 'You already have a shift at this time.';
      }
    }

    // 2. Check location capacity (max 2 employees per slot)
    final slotShifts = await _firestore
        .collection('shifts')
        .where('location', isEqualTo: shift.location)
        .where('date', isEqualTo: Timestamp.fromDate(shift.date))
        .get();

    int concurrentShifts = 0;
    for (var doc in slotShifts.docs) {
      final existingShift = ShiftModel.fromMap(doc.data(), doc.id);
      if (shift.startTime.isBefore(existingShift.endTime) &&
          shift.endTime.isAfter(existingShift.startTime)) {
        concurrentShifts++;
      }
    }

    if (concurrentShifts >= 2) {
      return 'This time slot is full (max 2 employees).';
    }

    // 3. Check daily capacity (max 22 hours per location)
    double dailyTotal = 0;
    for (var doc in slotShifts.docs) {
      final existingShift = ShiftModel.fromMap(doc.data(), doc.id);
      dailyTotal += existingShift.durationInHours;
    }

    if (dailyTotal + shift.durationInHours > 22.1) { // 22.1 to account for float precision
      return 'Daily capacity for this location is reached (22h).';
    }

    await _firestore.collection('shifts').add(shift.toMap());
    return null; // Success
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

final shiftRepositoryProvider = Provider((ref) => ShiftRepository());

