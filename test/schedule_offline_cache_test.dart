import 'dart:convert';

import 'package:fivetogo_scheduler/core/pwa/schedule_offline_cache.dart';
import 'package:fivetogo_scheduler/features/scheduling/domain/shift_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('serializes and deserializes ShiftModel in the existing cache format',
      () async {
    final original = ShiftModel(
      id: 'shift-gara-sep',
      userId: 'firebase-employee-1',
      userName: 'Veronica',
      date: DateTime(2026, 9, 10),
      startTime: DateTime.parse('2026-09-10T07:00:00.000').toLocal(),
      endTime: DateTime.parse('2026-09-10T18:00:00.000').toLocal(),
      type: 'FULL',
      location: 'Gara',
      status: 'approved',
    );

    final cache = ScheduleOfflineCache();
    await cache.saveShifts('firebase-employee-1', [original]);
    final loaded = await cache.loadShifts('firebase-employee-1');

    expect(loaded, hasLength(1));
    expect(loaded.first.id, original.id);
    expect(loaded.first.userId, 'firebase-employee-1');
    expect(loaded.first.userName, 'Veronica');
    expect(loaded.first.location, 'Gara');
    expect(loaded.first.type, 'FULL');
    expect(loaded.first.status, 'approved');
    expect(loaded.first.date, original.date);
    expect(loaded.first.startTime, original.startTime);
    expect(loaded.first.endTime, original.endTime);
  });

  test('loads previously cached camelCase ShiftModel JSON', () async {
    const userId = 'firebase-employee-1';
    final stored = [
      {
        'id': 'legacy-1',
        'userId': userId,
        'userName': 'Veronica',
        'date': '2026-09-10T00:00:00.000',
        'startTime': '2026-09-10T07:00:00.000',
        'endTime': '2026-09-10T18:00:00.000',
        'type': 'FULL',
        'location': 'Gara',
        'status': 'approved',
      },
    ];
    SharedPreferences.setMockInitialValues({
      'offline_shifts_$userId': jsonEncode(stored),
    });

    final loaded = await ScheduleOfflineCache().loadShifts(userId);
    expect(loaded, hasLength(1));
    expect(loaded.first.id, 'legacy-1');
    expect(loaded.first.userId, userId);
    expect(loaded.first.location, 'Gara');
    expect(loaded.first.userName, 'Veronica');
    expect(loaded.first.date, DateTime.parse('2026-09-10T00:00:00.000'));
  });

  test('API-mapped ShiftModel remains compatible with the cache JSON', () async {
    final apiMapped = ShiftModel.fromApiJson(
      {
        'id': 'shift-gara-sep',
        'user_id': 'cb3355e2-1bad-4826-8796-ca1734ce288a',
        'location_id': 'ff63f35a-ddd1-449e-9021-33ee78e2261a',
        'work_date': '2026-09-10',
        'start_at': '2026-09-10T04:00:00.000Z',
        'end_at': '2026-09-10T15:00:00.000Z',
        'type': 'FULL',
        'status': 'approved',
      },
      firebaseUid: 'firebase-employee-1',
      locationName: 'Gara',
      userName: 'Veronica',
    );

    final cache = ScheduleOfflineCache();
    await cache.saveShifts(apiMapped.userId, [apiMapped]);
    final loaded = await cache.loadShifts(apiMapped.userId);

    expect(loaded.first.userId, 'firebase-employee-1');
    expect(loaded.first.location, 'Gara');
    expect(loaded.first.userName, 'Veronica');
    expect(loaded.first.date, DateTime(2026, 9, 10));
    expect(loaded.first.startTime, apiMapped.startTime);
    expect(loaded.first.endTime, apiMapped.endTime);
  });
}
