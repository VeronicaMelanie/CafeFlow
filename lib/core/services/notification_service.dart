import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Notification settings
  bool _shiftRemindersEnabled = true;
  bool _scheduleUpdatesEnabled = true;
  bool _vacationStatusEnabled = true;
  bool _soundEnabled = true;

  Future<void> init() async {
    await _loadSettings();

    if (kIsWeb) {
      await FirebaseMessaging.instance.requestPermission();
      return;
    }

    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    // Handle background messages
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _shiftRemindersEnabled = prefs.getBool('shift_reminders') ?? true;
    _scheduleUpdatesEnabled = prefs.getBool('schedule_updates') ?? true;
    _vacationStatusEnabled = prefs.getBool('vacation_status') ?? true;
    _soundEnabled = prefs.getBool('notification_sound') ?? true;
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_sound', enabled);
  }

  Future<void> setShiftReminders(bool enabled) async {
    _shiftRemindersEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shift_reminders', enabled);
  }

  Future<void> setScheduleUpdates(bool enabled) async {
    _scheduleUpdatesEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('schedule_updates', enabled);
  }

  Future<void> setVacationStatus(bool enabled) async {
    _vacationStatusEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vacation_status', enabled);
  }

  Future<void> scheduleShiftReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (kIsWeb || !_shiftRemindersEnabled) return;
    if (scheduledDate.isBefore(DateTime.now())) return;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'shift_reminders',
          'Shift Reminders',
          channelDescription: 'Notifications for upcoming coffee shop shifts',
          importance: Importance.max,
          priority: Priority.high,
          playSound: _soundEnabled,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'instant_notifications',
          'Instant Notifications',
          channelDescription: 'Instant notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  bool get shiftRemindersEnabled => _shiftRemindersEnabled;
  bool get scheduleUpdatesEnabled => _scheduleUpdatesEnabled;
  bool get vacationStatusEnabled => _vacationStatusEnabled;
  bool get soundEnabled => _soundEnabled;
}
