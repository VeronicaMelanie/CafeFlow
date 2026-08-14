import 'package:fivetogo_scheduler/features/cleaning/data/cleaning_notification_helper.dart';
import 'package:fivetogo_scheduler/features/cleaning/domain/cleaning_list_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('admin completion notification does not repeatedly fire', () async {
    await CleaningNotificationHelper.notifyAdminAllTasksCompleted(
      employeeName: 'Veronica',
      listKey: CleaningListKey.closing,
      employeeId: 'employee-1',
      weekId: '2026-W33',
      location: 'Gara',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(
        'cleaning_admin_alert_employee-1_closing_2026-W33_Gara',
      ),
      isTrue,
    );

    await CleaningNotificationHelper.notifyAdminAllTasksCompleted(
      employeeName: 'Veronica',
      listKey: CleaningListKey.closing,
      employeeId: 'employee-1',
      weekId: '2026-W33',
      location: 'Gara',
    );
  });

  test('admin completion notification can fire again after reset', () async {
    await CleaningNotificationHelper.notifyAdminAllTasksCompleted(
      employeeName: 'Gabriel',
      listKey: CleaningListKey.tuesday,
      employeeId: 'employee-2',
      weekId: '2026-W33',
      location: 'Gara',
    );
    await CleaningNotificationHelper.resetAdminAlertForTesting(
      employeeId: 'employee-2',
      listKey: CleaningListKey.tuesday,
      weekId: '2026-W33',
      location: 'Gara',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(
        'cleaning_admin_alert_employee-2_tuesday_2026-W33_Gara',
      ),
      isNull,
    );
  });

  test('closing reminder only schedules for closing list key', () async {
    await CleaningNotificationHelper.scheduleClosingReminder(
      employeeId: 'employee-1',
      shiftEndTime: DateTime.now().add(const Duration(hours: 2)),
      listKey: CleaningListKey.monday,
    );
  });
}
