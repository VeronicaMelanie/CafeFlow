import 'dart:io';

import 'package:fivetogo_scheduler/core/api/api_exception.dart';
import 'package:fivetogo_scheduler/features/auth/data/users_repository.dart';
import 'package:fivetogo_scheduler/features/locations/data/location_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/data/availability_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/domain/availability_model.dart';
import 'package:fivetogo_scheduler/features/scheduling/domain/shift_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/api_test_harness.dart';
import 'helpers/scheduling_api_fixtures.dart';

void main() {
  test('maps GET /api/availability JSON with Firebase UID and DATE/TIME', () {
    const json = {
      'id': 'avail-custom-sep',
      'user_id': 'cb3355e2-1bad-4826-8796-ca1734ce288a',
      'work_date': '2026-09-23',
      'shift_type': 'custom_hours',
      'custom_start_time': '04:00:00.000',
      'custom_end_time': '10:00:00.000',
      'submitted_at': '2026-08-09T08:32:16.801Z',
    };

    final model = AvailabilityModel.fromApiJson(
      json,
      firebaseUid: 'firebase-employee-1',
    );

    expect(model.id, 'avail-custom-sep');
    expect(model.userId, 'firebase-employee-1');
    expect(model.userId, isNot('cb3355e2-1bad-4826-8796-ca1734ce288a'));
    expect(model.date, DateTime(2026, 9, 23));
    expect(model.date.isUtc, isFalse);
    expect(model.shiftType, AvailabilityShiftType.customHours);
    expect(model.customStartTime, DateTime(2026, 9, 23, 4, 0, 0));
    expect(model.customEndTime, DateTime(2026, 9, 23, 10, 0, 0));
    expect(model.submissionTimestamp, isNotNull);
  });

  test('maps Firebase UID from PostgreSQL user_id and filters user/month/day',
      () async {
    final paths = <String>[];
    final repos = buildSchedulingRepos(
      schedulingApiMock(capturedPaths: paths),
    );
    final month = DateTime(2026, 9, 1);

    final forUser = await repos.availability.getUserAvailabilityForMonth(
      'firebase-employee-1',
      month,
    );
    expect(paths, contains('/api/availability'));
    expect(forUser.map((e) => e.id), ['avail-full-sep', 'avail-custom-sep']);
    expect(
      forUser.every((e) => e.userId == 'firebase-employee-1'),
      isTrue,
    );
    expect(
      forUser.every((e) => e.date.year == 2026 && e.date.month == 9),
      isTrue,
    );

    final full = forUser.firstWhere((e) => e.id == 'avail-full-sep');
    expect(full.date, DateTime(2026, 9, 10));
    expect(full.shiftType, AvailabilityShiftType.fullTime);
    expect(full.customStartTime, isNull);

    final custom = forUser.firstWhere((e) => e.id == 'avail-custom-sep');
    expect(custom.customStartTime, DateTime(2026, 9, 23, 4));
    expect(custom.customEndTime, DateTime(2026, 9, 23, 10));

    final onDay = await repos.availability.getForUserOnDay(
      'firebase-employee-1',
      DateTime(2026, 9, 10),
    );
    expect(onDay?.id, 'avail-full-sep');

    final missingDay = await repos.availability.getForUserOnDay(
      'firebase-employee-1',
      DateTime(2026, 9, 11),
    );
    expect(missingDay, isNull);

    final august = await repos.availability.getUserAvailabilityForMonth(
      'firebase-employee-1',
      DateTime(2026, 8, 1),
    );
    expect(august.map((e) => e.id), ['avail-aug']);

    final admin = await repos.availability.getUserAvailabilityForMonth(
      'firebase-admin-1',
      month,
    );
    expect(admin.map((e) => e.id), ['avail-admin-sep']);

    final allMonth = await repos.availability.getAvailabilityForMonth(month);
    expect(
      allMonth.map((e) => e.id),
      containsAll(['avail-full-sep', 'avail-custom-sep', 'avail-admin-sep']),
    );
    expect(allMonth.any((e) => e.id == 'avail-unknown-user'), isFalse);
    expect(allMonth.any((e) => e.id == 'avail-aug'), isFalse);
  });

  test('propagates HTTP errors', () async {
    final repos = buildSchedulingRepos(schedulingApiMock(statusCode: 500));
    await expectLater(
      repos.availability.getAllAvailability(),
      throwsA(
        isA<ApiHttpException>().having((e) => e.statusCode, 'statusCode', 500),
      ),
    );
  });

  test('does not call the API when no user is signed in', () async {
    var calls = 0;
    final api = buildTestApiClient(
      tokenSource: FakeTokenSource([null]),
      httpClient: MockClient((request) async {
        calls += 1;
        return http.Response('[]', 200);
      }),
    );
    final repository = AvailabilityRepository(
      apiClient: api,
      usersRepository: UsersRepository(
        apiClient: api,
        locationRepository: LocationRepository(apiClient: api),
      ),
    );

    await expectLater(
      repository.getAllAvailability(),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
    expect(calls, 0);
  });

  test('creates availability with POST and maps DATE/TIME without UTC', () async {
    final requests = <http.Request>[];
    final repos = buildSchedulingRepos(
      schedulingApiMock(
        onWrite: (request) async {
          requests.add(request);
          expect(request.method, 'POST');
          expect(request.url.path, '/api/availability');
          return http.Response(
            '{"id":"avail-new","user_id":"cb3355e2-1bad-4826-8796-ca1734ce288a",'
            '"work_date":"2026-10-05","shift_type":"custom_hours",'
            '"custom_start_time":"07:30:00","custom_end_time":"12:15:00",'
            '"submitted_at":"2026-08-15T12:00:00.000Z"}',
            201,
          );
        },
      ),
    );

    await repos.availability.saveAvailability(
      userId: 'firebase-employee-1',
      day: DateTime(2026, 10, 5, 22, 0),
      shiftType: AvailabilityShiftType.customHours,
      customStart: DateTime(2026, 10, 5, 7, 30),
      customEnd: DateTime(2026, 10, 5, 12, 15),
    );

    expect(requests, hasLength(1));
    expect(requests.single.body, contains('"work_date":"2026-10-05"'));
    expect(requests.single.body, contains('"shift_type":"custom_hours"'));
    expect(requests.single.body, contains('"custom_start_time":"07:30:00"'));
    expect(requests.single.body, contains('"custom_end_time":"12:15:00"'));
    expect(requests.single.body.contains('user_id'), isFalse);
  });

  test('updates existing availability with PATCH using the PostgreSQL UUID',
      () async {
    final requests = <http.Request>[];
    final repos = buildSchedulingRepos(
      schedulingApiMock(
        onWrite: (request) async {
          requests.add(request);
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/availability/avail-full-sep');
          return http.Response(
            '{"id":"avail-full-sep","user_id":"cb3355e2-1bad-4826-8796-ca1734ce288a",'
            '"work_date":"2026-09-10","shift_type":"custom_hours",'
            '"custom_start_time":"08:00:00","custom_end_time":"13:00:00",'
            '"submitted_at":"2026-08-09T08:32:15.873Z"}',
            200,
          );
        },
      ),
    );

    await repos.availability.saveAvailability(
      userId: 'firebase-employee-1',
      day: DateTime(2026, 9, 10),
      shiftType: AvailabilityShiftType.customHours,
      customStart: DateTime(2026, 9, 10, 8),
      customEnd: DateTime(2026, 9, 10, 13),
    );

    expect(requests, hasLength(1));
    expect(requests.single.body, contains('"work_date":"2026-09-10"'));
    expect(requests.single.body, contains('"custom_start_time":"08:00:00"'));
  });

  test('deletes availability by PostgreSQL UUID', () async {
    final requests = <http.Request>[];
    final repos = buildSchedulingRepos(
      schedulingApiMock(
        onWrite: (request) async {
          requests.add(request);
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/availability/avail-full-sep');
          return http.Response('', 204);
        },
      ),
    );

    await repos.availability.deleteForUserOnDay(
      'firebase-employee-1',
      DateTime(2026, 9, 10),
    );

    expect(requests, hasLength(1));
  });

  test('propagates write HTTP errors instead of treating them as success',
      () async {
    final repos = buildSchedulingRepos(
      schedulingApiMock(
        onWrite: (request) async {
          expect(request.method, 'POST');
          return http.Response('{"error":"invalid_availability"}', 400);
        },
      ),
    );

    await expectLater(
      repos.availability.saveAvailability(
        userId: 'firebase-employee-1',
        day: DateTime(2026, 10, 6),
        shiftType: AvailabilityShiftType.fullTime,
      ),
      throwsA(
        isA<ApiHttpException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.errorCode, 'errorCode', 'invalid_availability'),
      ),
    );
  });

  test('availability UI and repository do not write Firestore', () {
    const files = [
      'lib/features/scheduling/data/availability_repository.dart',
      'lib/features/scheduling/presentation/availability_days_editor_screen.dart',
      'lib/features/scheduling/presentation/submit_availability_screen.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source.contains('cloud_firestore'), isFalse, reason: path);
      expect(source.contains('FirebaseFirestore'), isFalse, reason: path);
      expect(source.contains("collection('availability')"), isFalse, reason: path);
    }

    final editor = File(
      'lib/features/scheduling/presentation/availability_days_editor_screen.dart',
    ).readAsStringSync();
    expect(editor.contains('saveAvailability'), isTrue);
    expect(editor.contains('.set('), isFalse);
    expect(editor.contains('.update('), isFalse);

    final submit = File(
      'lib/features/scheduling/presentation/submit_availability_screen.dart',
    ).readAsStringSync();
    expect(submit.contains('saveAvailability'), isTrue);
    expect(submit.contains('deleteForUserOnDay'), isTrue);
  });
}
