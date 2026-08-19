import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/presentation/auth_providers.dart';
import '../presentation/scheduling_providers.dart';
import '../utils/scheduling_month_utils.dart';

/// First login during the 20–30 window sends "submit availability".
/// From the 27th, reminds employees who still have zero days marked.
class SchedulingWindowAutomation {
  SchedulingWindowAutomation._();

  static Future<void> maybeRun(WidgetRef ref) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final now = DateTime.now();
    final targetMonth = DateTime(now.year, now.month + 1, 1);
    if (!SchedulingMonthUtils.isAvailabilityWindowOpen(targetMonth, now)) {
      return;
    }

    final window = SchedulingMonthUtils.availabilityWindowFor(targetMonth);
    final docId = '${now.year}_${now.month.toString().padLeft(2, '0')}';
    final doc = FirebaseFirestore.instance
        .collection('scheduling_automation')
        .doc(docId);
    final snap = await doc.get();
    final data = snap.data() ?? <String, dynamic>{};
    final monthLabel = DateFormat('MMMM yyyy').format(targetMonth);
    final auth = ref.read(authRepositoryProvider);

    if (data['openedNotified'] != true) {
      await auth.sendNotificationToAllEmployees(
        title: 'Disponibilitatea este deschisă',
        body:
            'Marchează zilele în care poți lucra în $monthLabel. Interval: ${DateFormat('d MMM').format(window.start)}–${DateFormat('d MMM').format(window.end)}.',
      );
      await doc.set({
        'openedNotified': true,
        'openedNotifiedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final remindFromDay = 27;
    if (now.day >= remindFromDay &&
        now.day <= window.end.day &&
        data['reminded'] != true) {
      final missing = await _uidsMissingAvailability(ref, targetMonth);
      if (missing.isNotEmpty) {
        await auth.sendNotificationToUids(
          uids: missing,
          title: 'Reminder: trimite disponibilitatea',
          body:
              'Nu ai marcat încă zile pentru $monthLabel. Intervalul se închide pe ${DateFormat('d MMM').format(window.end)}.',
        );
      }
      await doc.set({
        'reminded': true,
        'remindedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  static Future<List<String>> _uidsMissingAvailability(
    WidgetRef ref,
    DateTime month,
  ) async {
    final employees = await ref
        .read(authRepositoryProvider)
        .getAllEmployees()
        .first;
    final submitted = await ref
        .read(availabilityRepositoryProvider)
        .getAvailabilityForMonth(month);
    final whoSubmitted = {for (final row in submitted) row.userId};
    return [
      for (final employee in employees)
        if (!whoSubmitted.contains(employee.uid)) employee.uid,
    ];
  }
}
