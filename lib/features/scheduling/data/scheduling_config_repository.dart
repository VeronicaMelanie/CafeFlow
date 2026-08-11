import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/scheduling_config_model.dart';
import '../utils/scheduling_month_utils.dart';

class SchedulingConfigRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('scheduling_config');

  Stream<SchedulingConfigModel?> watchConfigForMonth(
    DateTime month, {
    String? location,
  }) {
    final year = month.year;
    final monthNum = month.month;

    if (location != null && location.isNotEmpty) {
      final locId = SchedulingMonthUtils.locationConfigDocId(
        year,
        monthNum,
        location,
      );
      final globalId =
          SchedulingMonthUtils.globalConfigDocId(year, monthNum);

      return _collection.doc(locId).snapshots().asyncExpand((locSnap) async* {
        if (locSnap.exists) {
          yield SchedulingConfigModel.fromMap(locSnap.data()!, locSnap.id);
          return;
        }
        await for (final globalSnap in _collection.doc(globalId).snapshots()) {
          if (globalSnap.exists) {
            yield SchedulingConfigModel.fromMap(
              globalSnap.data()!,
              globalSnap.id,
            );
          } else {
            yield null;
          }
        }
      });
    }

    final globalId = SchedulingMonthUtils.globalConfigDocId(year, monthNum);
    return _collection.doc(globalId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return SchedulingConfigModel.fromMap(snap.data()!, snap.id);
    });
  }

  Future<void> setSchedulingEnabled({
    required int year,
    required int month,
    String? location,
    required bool enabled,
    required String adminUid,
  }) async {
    final docId = location != null && location.isNotEmpty
        ? SchedulingMonthUtils.locationConfigDocId(year, month, location)
        : SchedulingMonthUtils.globalConfigDocId(year, month);

    await _collection.doc(docId).set({
      'year': year,
      'month': month,
      if (location != null && location.isNotEmpty) 'location': location,
      'schedulingEnabled': enabled,
      'lockedMonth': false,
      'enabledAt': FieldValue.serverTimestamp(),
      'enabledBy': adminUid,
    }, SetOptions(merge: true));
  }

  Future<void> setMonthLocked({
    required int year,
    required int month,
    required bool locked,
    String? location,
  }) async {
    final docId = location != null && location.isNotEmpty
        ? SchedulingMonthUtils.locationConfigDocId(year, month, location)
        : SchedulingMonthUtils.globalConfigDocId(year, month);

    await _collection.doc(docId).set({
      'year': year,
      'month': month,
      if (location != null && location.isNotEmpty) 'location': location,
      'lockedMonth': locked,
    }, SetOptions(merge: true));
  }

  Future<List<SchedulingConfigModel>> listConfigsForYear(int year) async {
    final snap = await _collection.where('year', isEqualTo: year).get();
    return snap.docs
        .map((d) => SchedulingConfigModel.fromMap(d.data(), d.id))
        .toList();
  }
}

/// Resolved state for employee availability UI.
class MonthSchedulingAccess {
  final bool calendarMonthLocked;
  final bool adminLockedMonth;
  final bool schedulingEnabled;
  final bool canEdit;

  const MonthSchedulingAccess({
    required this.calendarMonthLocked,
    required this.adminLockedMonth,
    required this.schedulingEnabled,
    required this.canEdit,
  });

  String? get bannerMessage {
    if (calendarMonthLocked || adminLockedMonth) {
      return 'Scheduling for this month is locked.';
    }
    if (!schedulingEnabled) {
      return 'Scheduling has not been opened yet. Please wait for your manager.';
    }
    return null;
  }
}

MonthSchedulingAccess resolveMonthAccess({
  required DateTime scheduleMonth,
  SchedulingConfigModel? config,
  DateTime? now,
}) {
  final calendarLocked =
      !SchedulingMonthUtils.isMonthEditable(scheduleMonth, now);
  final adminOpen = config?.schedulingEnabled ?? false;
  final adminLocked = config?.lockedMonth ?? false;

  return MonthSchedulingAccess(
    calendarMonthLocked: calendarLocked,
    adminLockedMonth: adminLocked,
    schedulingEnabled: adminOpen,
    canEdit: !calendarLocked && !adminLocked && adminOpen,
  );
}
