import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/availability_model.dart';
import '../domain/shift_type.dart';
import '../utils/scheduling_month_utils.dart';

class AvailabilityRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('availability');

  Stream<List<AvailabilityModel>> watchUserAvailabilityForMonth(
    String userId,
    DateTime month,
  ) {
    final start = SchedulingMonthUtils.monthStart(month);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    return _collection
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AvailabilityModel.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  Future<AvailabilityModel?> getForUserOnDay(String userId, DateTime day) async {
    final normalized = DateTime(day.year, day.month, day.day);
    final snap = await _collection
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: Timestamp.fromDate(normalized))
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return AvailabilityModel.fromMap(doc.data(), doc.id);
  }

  Future<String?> validatePartTimeHours({
    required DateTime day,
    required DateTime start,
    required DateTime end,
  }) async {
    if (!end.isAfter(start)) {
      return 'End time must be after start time.';
    }

    final open = DateTime(
      day.year,
      day.month,
      day.day,
      SchedulingMonthUtils.shopOpenHour,
    );
    final close = DateTime(
      day.year,
      day.month,
      day.day,
      SchedulingMonthUtils.shopCloseHour,
    );

    if (start.isBefore(open) || end.isAfter(close)) {
      return 'Hours must be between 07:00 and 18:00.';
    }

    final durationHours = end.difference(start).inMinutes / 60.0;
    if (durationHours <= 0) {
      return 'Invalid time interval.';
    }

    return null;
  }

  Future<void> saveAvailability({
    required String userId,
    required DateTime day,
    required AvailabilityShiftType shiftType,
    DateTime? customStart,
    DateTime? customEnd,
    String? existingDocId,
  }) async {
    final normalized = DateTime(day.year, day.month, day.day);

    DateTime? start;
    DateTime? end;
    if (shiftType == AvailabilityShiftType.customHours) {
      start = customStart;
      end = customEnd;
    }

    final model = AvailabilityModel(
      id: existingDocId ?? '',
      userId: userId,
      date: normalized,
      shiftType: shiftType,
      customStartTime: start,
      customEndTime: end,
    );

    final data = model.toMap(useServerTimestamp: existingDocId == null);

    if (existingDocId != null) {
      await _collection.doc(existingDocId).set(data, SetOptions(merge: true));
    } else {
      await _collection.add(data);
    }
  }

  Future<void> deleteAvailability(String docId) async {
    await _collection.doc(docId).delete();
  }

  Future<void> deleteForUserOnDay(String userId, DateTime day) async {
    final existing = await getForUserOnDay(userId, day);
    if (existing != null) {
      await deleteAvailability(existing.id);
    }
  }

  /// Total hours the user has submitted for [month] (availability, not assigned shifts).
  double totalSubmittedHours(List<AvailabilityModel> entries) {
    return entries.fold(0.0, (sum, e) => sum + e.durationInHours);
  }
}
