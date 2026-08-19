import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/notification_service.dart';
import '../domain/cleaning_list_key.dart';

/// Modular cleaning checklist notifications.
class CleaningNotificationHelper {
  CleaningNotificationHelper._();

  static const _reminderBaseId = 5000;
  static const _adminAlertBaseId = 6000;

  static Future<void> scheduleClosingReminder({
    required String employeeId,
    required DateTime shiftEndTime,
    required CleaningListKey listKey,
  }) async {
    if (listKey != CleaningListKey.closing) return;

    final reminderTime = shiftEndTime.subtract(const Duration(minutes: 30));
    await NotificationService().scheduleShiftReminder(
      id: _reminderBaseId + employeeId.hashCode.abs() % 900,
      title: 'Reminder curățenie',
      body: 'Nu uita să completezi sarcinile de curățenie.',
      scheduledDate: reminderTime,
    );
  }

  static Future<void> notifyAdminAllTasksCompleted({
    required String employeeName,
    required CleaningListKey listKey,
    required String employeeId,
    required String weekId,
    required String location,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final alertKey =
        'cleaning_admin_alert_${employeeId}_${listKey.name}_${weekId}_$location';
    if (prefs.getBool(alertKey) == true) return;

    await prefs.setBool(alertKey, true);
    try {
      await NotificationService().showInstantNotification(
        title: 'Lista de curățenie este completă',
        body: '$employeeName a bifat toate sarcinile de ${listKey.label}.',
      );
    } catch (_) {
      // Platform notifications are unavailable in unit tests.
    }
  }

  static Future<void> resetAdminAlertForTesting({
    required String employeeId,
    required CleaningListKey listKey,
    required String weekId,
    required String location,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final alertKey =
        'cleaning_admin_alert_${employeeId}_${listKey.name}_${weekId}_$location';
    await prefs.remove(alertKey);
  }

  static int adminNotificationId(String employeeId, CleaningListKey listKey) =>
      _adminAlertBaseId + (employeeId.hashCode + listKey.index).abs() % 900;
}
