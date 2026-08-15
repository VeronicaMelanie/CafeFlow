import 'dart:convert';
import 'dart:io';

import 'package:fivetogo_scheduler/core/api/api_datetime.dart';
import 'package:fivetogo_scheduler/core/api/api_exception.dart';
import 'package:fivetogo_scheduler/features/auth/data/users_repository.dart';
import 'package:fivetogo_scheduler/features/locations/data/location_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/data/shift_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/domain/shift_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/api_test_harness.dart';
import 'helpers/scheduling_api_fixtures.dart';

void main() {
  test('maps GET /api/shifts JSON with UID, location name, and timestamptz', () {
    const json = {
      'id': 'shift-gara-sep',
      'user_id': 'cb3355e2-1bad-4826-8796-ca1734ce288a',
      'location_id': 'ff63f35a-ddd1-449e-9021-33ee78e2261a',
      'work_date': '2026-09-10',
      'start_at': '2026-09-10T04:00:00.000Z',
      'end_at': '2026-09-10T15:00:00.000Z',
      'type': 'FULL',
      'status': 'approved',
    };

    final model = ShiftModel.fromApiJson(
      json,
      firebaseUid: 'firebase-employee-1',
      locationName: 'Gara',
      userName: 'Veronica',
    );

    expect(model.userId, 'firebase-employee-1');
    expect(model.userId, isNot('cb3355e2-1bad-4826-8796-ca1734ce288a'));
    expect(model.location, 'Gara');
    expect(model.location, isNot('ff63f35a-ddd1-449e-9021-33ee78e2261a'));
    expect(model.userName, 'Veronica');
    expect(model.date, DateTime(2026, 9, 10));
    expect(model.startTime.toUtc(), DateTime.utc(2026, 9, 10, 4));
    expect(model.endTime.toUtc(), DateTime.utc(2026, 9, 10, 15));
    expect(model.type, 'FULL');
    expect(model.status, 'approved');
  });

  test('filters by month, user, and location name from the catalog', () async {
    final paths = <String>[];
    final repos = buildSchedulingRepos(
      schedulingApiMock(capturedPaths: paths),
    );
    final month = DateTime(2026, 9, 1);

    final all = await repos.shifts.getAllShifts();
    expect(paths, contains('/api/shifts'));
    expect(all.map((s) => s.id), ['shift-gara-sep', 'shift-ag-sep', 'shift-gara-aug']);
    expect(all.any((s) => s.id == 'shift-unknown-user'), isFalse);
    expect(all.every((s) => s.userId == 'firebase-employee-1'), isTrue);
    expect(all.map((s) => s.location).toSet(), {'Gara', 'Avantgarden'});
    expect(all.every((s) => s.userName == 'Veronica'), isTrue);

    final gara = await repos.shifts.getShiftsForMonth(month, 'Gara').first;
    expect(gara.map((s) => s.id), ['shift-gara-sep']);
    expect(gara.first.location, 'Gara');

    final avantgarden =
        await repos.shifts.getShiftsForMonth(month, 'Avantgarden').first;
    expect(avantgarden.map((s) => s.id), ['shift-ag-sep']);
    expect(avantgarden.first.location, 'Avantgarden');

    final userMonth = await repos.shifts
        .getUserShiftsForMonth('firebase-employee-1', month)
        .first;
    expect(userMonth.map((s) => s.id), ['shift-gara-sep', 'shift-ag-sep']);

    final employee = await repos.shifts.getEmployeeShifts('firebase-employee-1');
    expect(
      employee.map((s) => s.id),
      ['shift-gara-sep', 'shift-ag-sep', 'shift-gara-aug'],
    );

    final day = await repos.shifts.getShiftsForDay(
      date: DateTime(2026, 9, 10),
      location: 'Gara',
    );
    expect(day.map((s) => s.id), ['shift-gara-sep']);

    final start = ApiDateTime.parseTimestamptz('2026-09-10T04:00:00.000Z');
    expect(gara.first.startTime, start);
  });

  test('ShiftRepository.test returns empty lists without calling the API',
      () async {
    final repository = ShiftRepository.test();
    expect(await repository.getAllShifts(), isEmpty);
    expect(await repository.getEmployeeShifts('anyone'), isEmpty);
    expect(
      await repository.getShiftsForMonth(DateTime(2026, 9), 'Gara').first,
      isEmpty,
    );
  });

  test('propagates HTTP errors', () async {
    final repos = buildSchedulingRepos(schedulingApiMock(statusCode: 500));
    await expectLater(
      repos.shifts.getAllShifts(),
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
    final repository = ShiftRepository(
      apiClient: api,
      usersRepository: UsersRepository(
        apiClient: api,
        locationRepository: LocationRepository(apiClient: api),
      ),
      locationRepository: LocationRepository(apiClient: api),
    );

    await expectLater(
      repository.getAllShifts(),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
    expect(calls, 0);
  });

  ShiftModel sampleShift({
    String id = '',
    String status = 'pending',
    String location = 'Gara',
  }) {
    return ShiftModel(
      id: id,
      userId: 'firebase-employee-1',
      userName: 'Veronica',
      date: DateTime(2026, 10, 6),
      startTime: DateTime(2026, 10, 6, 7, 30),
      endTime: DateTime(2026, 10, 6, 18, 0),
      type: 'FULL',
      location: location,
      status: status,
    );
  }

  test('creates a shift with postgres user UUID, location name, DATE and TIMESTAMPTZ',
      () async {
    final requests = <http.Request>[];
    final repos = buildSchedulingRepos(
      schedulingApiMock(
        onWrite: (request) async {
          requests.add(request);
          expect(request.method, 'POST');
          expect(request.url.path, '/api/shifts');
          return http.Response(
            '{"id":"shift-new","user_id":"cb3355e2-1bad-4826-8796-ca1734ce288a",'
            '"location_id":"ff63f35a-ddd1-449e-9021-33ee78e2261a",'
            '"work_date":"2026-10-06","start_at":"2026-10-06T04:30:00.000Z",'
            '"end_at":"2026-10-06T15:00:00.000Z","type":"FULL","status":"pending"}',
            201,
          );
        },
      ),
    );

    await repos.shifts.createShift(sampleShift());

    expect(requests, hasLength(1));
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['user_id'], 'cb3355e2-1bad-4826-8796-ca1734ce288a');
    expect(body['user_id'], isNot('firebase-employee-1'));
    expect(body['location'], 'Gara');
    expect(body.containsKey('location_id'), isFalse);
    expect(body['work_date'], '2026-10-06');
    expect(body['start_at'], ApiDateTime.formatTimestamptz(DateTime(2026, 10, 6, 7, 30)));
    expect(body['end_at'], ApiDateTime.formatTimestamptz(DateTime(2026, 10, 6, 18)));
    expect(body.containsKey('userName'), isFalse);
    expect(body['status'], 'pending');
    expect(ApiDateTime.formatTimeOnly(DateTime(2026, 10, 6, 7, 30)), '07:30:00');
  });

  test('updates a shift with PATCH using the PostgreSQL UUID', () async {
    final requests = <http.Request>[];
    final repos = buildSchedulingRepos(
      schedulingApiMock(
        onWrite: (request) async {
          requests.add(request);
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/shifts/shift-gara-sep');
          return http.Response(
            '{"id":"shift-gara-sep","user_id":"cb3355e2-1bad-4826-8796-ca1734ce288a",'
            '"location_id":"ff63f35a-ddd1-449e-9021-33ee78e2261a",'
            '"work_date":"2026-10-06","start_at":"2026-10-06T04:30:00.000Z",'
            '"end_at":"2026-10-06T15:00:00.000Z","type":"FULL","status":"approved"}',
            200,
          );
        },
      ),
    );

    await repos.shifts.updateShift(
      sampleShift(id: 'shift-gara-sep', status: 'approved'),
    );

    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body.containsKey('user_id'), isFalse);
    expect(body['status'], 'approved');
    expect(body['location'], 'Gara');
  });

  test('deletes a shift by PostgreSQL UUID', () async {
    final requests = <http.Request>[];
    final repos = buildSchedulingRepos(
      schedulingApiMock(
        onWrite: (request) async {
          requests.add(request);
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/shifts/shift-gara-sep');
          return http.Response('', 204);
        },
      ),
    );

    await repos.shifts.deleteShift('shift-gara-sep');
    expect(requests, hasLength(1));
  });

  test('publishes a draft schedule as a bulk approved write', () async {
    final requests = <http.Request>[];
    final repos = buildSchedulingRepos(
      schedulingApiMock(
        onWrite: (request) async {
          requests.add(request);
          expect(request.method, 'POST');
          expect(request.url.path, '/api/shifts/bulk');
          return http.Response('[]', 201);
        },
      ),
    );

    await repos.shifts.publishShifts([
      sampleShift(location: 'Gara'),
      sampleShift(location: 'Avantgarden'),
    ]);

    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    final shifts = body['shifts'] as List<dynamic>;
    expect(shifts, hasLength(2));
    expect(shifts[0]['user_id'], 'cb3355e2-1bad-4826-8796-ca1734ce288a');
    expect(shifts[0]['location'], 'Gara');
    expect(shifts[1]['location'], 'Avantgarden');
    expect(shifts[0]['status'], 'approved');
    expect(shifts[0].containsKey('userName'), isFalse);
  });

  test('propagates write HTTP errors', () async {
    final repos = buildSchedulingRepos(
      schedulingApiMock(
        onWrite: (request) async {
          return http.Response('{"error":"forbidden"}', 403);
        },
      ),
    );

    await expectLater(
      repos.shifts.createShift(sampleShift()),
      throwsA(
        isA<ApiHttpException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.errorCode, 'errorCode', 'forbidden'),
      ),
    );
  });

  test('shift UI, repository, and scheduling service do not write Firestore', () {
    const files = [
      'lib/features/scheduling/data/shift_repository.dart',
      'lib/features/scheduling/domain/shift_model.dart',
      'lib/features/scheduling/data/scheduling_service.dart',
      'lib/features/admin/presentation/manage_schedule_screen.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source.contains('cloud_firestore'), isFalse, reason: path);
      expect(source.contains('FirebaseFirestore'), isFalse, reason: path);
      expect(source.contains("collection('shifts')"), isFalse, reason: path);
    }

    final repo = File(
      'lib/features/scheduling/data/shift_repository.dart',
    ).readAsStringSync();
    expect(repo.contains('/api/shifts'), isTrue);
    expect(repo.contains('postJson'), isTrue);
    expect(repo.contains('patchJson'), isTrue);
    expect(repo.contains('/api/shifts/bulk'), isTrue);

    final service = File(
      'lib/features/scheduling/data/scheduling_service.dart',
    ).readAsStringSync();
    expect(service.contains('publishShifts'), isTrue);
    expect(service.contains('generateDraftSchedule'), isTrue);

    final screen = File(
      'lib/features/admin/presentation/manage_schedule_screen.dart',
    ).readAsStringSync();
    expect(screen.contains('publishSchedule'), isTrue);
    expect(screen.contains('invalidate'), isTrue);

    final auth = File('lib/features/auth/data/auth_repository.dart').readAsStringSync();
    expect(auth.contains("collection('users')"), isTrue);
  });
}
