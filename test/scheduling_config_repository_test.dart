import 'dart:convert';
import 'dart:io';

import 'package:fivetogo_scheduler/core/api/api_exception.dart';
import 'package:fivetogo_scheduler/features/auth/data/users_repository.dart';
import 'package:fivetogo_scheduler/features/locations/data/location_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/data/scheduling_config_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/domain/scheduling_config_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/api_test_harness.dart';
import 'helpers/scheduling_api_fixtures.dart';

void main() {
  test('maps GET /api/scheduling JSON without inventing null limits', () {
    const json = {
      'id': 'sched-1',
      'year': 2026,
      'month': 9,
      'location_id': 'ff63f35a-ddd1-449e-9021-33ee78e2261a',
      'scheduling_enabled': true,
      'locked_month': false,
      'enabled_by': '2583717c-1d7a-4901-8788-a8096cfdf8e3',
      'enabled_at': '2026-08-14T07:28:02.526Z',
      'max_hours_per_day': null,
      'max_employees_per_shift': null,
    };

    final model = SchedulingConfigModel.fromApiJson(
      json,
      locationName: 'Gara',
      enabledByFirebaseUid: 'firebase-admin-1',
    );

    expect(model.id, 'sched-1');
    expect(model.year, 2026);
    expect(model.month, 9);
    expect(model.location, 'Gara');
    expect(model.schedulingEnabled, isTrue);
    expect(model.lockedMonth, isFalse);
    expect(model.enabledBy, 'firebase-admin-1');
    expect(model.maxHoursPerDay, isNull);
    expect(model.maxEmployeesPerShift, isNull);
    expect(model.enabledAt, isNotNull);
  });

  test('reads API configs and maps UUID location/enabled_by to names/UIDs',
      () async {
    final paths = <String>[];
    final repos = buildSchedulingRepos(
      schedulingApiMock(capturedPaths: paths),
    );

    final configs = await repos.scheduling.listConfigs();
    expect(paths, contains('/api/scheduling'));
    expect(configs, hasLength(2));

    final global = configs.firstWhere((c) => c.id == 'sched-global-sep');
    expect(global.location, isNull);
    expect(global.isGlobal, isTrue);
    expect(global.schedulingEnabled, isTrue);
    expect(global.enabledBy, 'firebase-admin-1');
    expect(global.maxHoursPerDay, isNull);
    expect(global.maxEmployeesPerShift, isNull);

    final gara = configs.firstWhere((c) => c.id == 'sched-gara-sep');
    expect(gara.location, 'Gara');
    expect(gara.location, isNot('ff63f35a-ddd1-449e-9021-33ee78e2261a'));
    expect(gara.schedulingEnabled, isFalse);
    expect(gara.lockedMonth, isTrue);
    expect(gara.maxHoursPerDay, 18);
    expect(gara.maxEmployeesPerShift, 3);
  });

  test('prefers location-specific config over global for the same month',
      () async {
    final repos = buildSchedulingRepos(schedulingApiMock());
    final month = DateTime(2026, 9, 1);

    final forGara = await repos.scheduling.getConfigForMonth(
      month,
      location: 'Gara',
    );
    expect(forGara?.id, 'sched-gara-sep');
    expect(forGara?.location, 'Gara');
    expect(forGara?.lockedMonth, isTrue);

    final forAvantgarden = await repos.scheduling.getConfigForMonth(
      month,
      location: 'Avantgarden',
    );
    expect(forAvantgarden?.id, 'sched-global-sep');
    expect(forAvantgarden?.isGlobal, isTrue);
  });

  test('propagates HTTP errors', () async {
    final repos = buildSchedulingRepos(schedulingApiMock(statusCode: 500));
    await expectLater(
      repos.scheduling.listConfigs(),
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
    final repository = SchedulingConfigRepository(
      apiClient: api,
      usersRepository: UsersRepository(
        apiClient: api,
        locationRepository: LocationRepository(apiClient: api),
      ),
      locationRepository: LocationRepository(apiClient: api),
    );

    await expectLater(
      repository.listConfigs(),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
    expect(calls, 0);
  });

  test('opens scheduling with POST when no exact config exists', () async {
    final requests = <http.Request>[];
    final repos = buildSchedulingRepos(
      schedulingApiMock(
        onWrite: (request) async {
          requests.add(request);
          expect(request.method, 'POST');
          expect(request.url.path, '/api/scheduling');
          return http.Response(
            '{"id":"sched-new","year":2026,"month":10,"location_id":null,'
            '"scheduling_enabled":true,"locked_month":false,'
            '"enabled_by":"2583717c-1d7a-4901-8788-a8096cfdf8e3",'
            '"enabled_at":"2026-08-15T12:00:00.000Z",'
            '"max_hours_per_day":null,"max_employees_per_shift":null}',
            201,
          );
        },
      ),
    );

    await repos.scheduling.setSchedulingEnabled(
      year: 2026,
      month: 10,
      enabled: true,
      adminUid: 'firebase-admin-1',
    );

    expect(requests, hasLength(1));
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['year'], 2026);
    expect(body['month'], 10);
    expect(body['scheduling_enabled'], isTrue);
    expect(body['locked_month'], isFalse);
    expect(body.containsKey('location'), isFalse);
    expect(body.containsKey('enabled_by'), isFalse);
    expect(body.containsKey('adminUid'), isFalse);
    expect(body.containsKey('max_hours_per_day'), isFalse);
  });

  test('opens location scheduling with the location name, not a UUID', () async {
    final requests = <http.Request>[];
    final repos = buildSchedulingRepos(
      schedulingApiMock(
        onWrite: (request) async {
          requests.add(request);
          expect(request.method, 'POST');
          return http.Response(
            '{"id":"sched-gara-oct","year":2026,"month":10,'
            '"location_id":"ff63f35a-ddd1-449e-9021-33ee78e2261a",'
            '"scheduling_enabled":true,"locked_month":false,'
            '"enabled_by":"2583717c-1d7a-4901-8788-a8096cfdf8e3",'
            '"enabled_at":"2026-08-15T12:00:00.000Z",'
            '"max_hours_per_day":null,"max_employees_per_shift":null}',
            201,
          );
        },
      ),
    );

    await repos.scheduling.setSchedulingEnabled(
      year: 2026,
      month: 10,
      location: 'Gara',
      enabled: true,
      adminUid: 'firebase-admin-1',
    );

    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['location'], 'Gara');
    expect(body['location'], isNot('ff63f35a-ddd1-449e-9021-33ee78e2261a'));
    expect(body.containsKey('location_id'), isFalse);
    expect(body.containsKey('enabled_by'), isFalse);
  });

  test('updates an existing exact config with PATCH instead of creating',
      () async {
    final requests = <http.Request>[];
    final repos = buildSchedulingRepos(
      schedulingApiMock(
        onWrite: (request) async {
          requests.add(request);
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/scheduling/sched-global-sep');
          return http.Response(
            '{"id":"sched-global-sep","year":2026,"month":9,"location_id":null,'
            '"scheduling_enabled":false,"locked_month":false,'
            '"enabled_by":"2583717c-1d7a-4901-8788-a8096cfdf8e3",'
            '"enabled_at":"2026-08-15T12:00:00.000Z",'
            '"max_hours_per_day":null,"max_employees_per_shift":null}',
            200,
          );
        },
      ),
    );

    await repos.scheduling.setSchedulingEnabled(
      year: 2026,
      month: 9,
      enabled: false,
      adminUid: 'firebase-admin-1',
    );

    expect(requests, hasLength(1));
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['scheduling_enabled'], isFalse);
    expect(body['locked_month'], isFalse);
    expect(body.containsKey('enabled_by'), isFalse);
  });

  test('does not PATCH the global row when writing a location-specific config',
      () async {
    final requests = <http.Request>[];
    final repos = buildSchedulingRepos(
      schedulingApiMock(
        onWrite: (request) async {
          requests.add(request);
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/scheduling/sched-gara-sep');
          return http.Response(
            '{"id":"sched-gara-sep","year":2026,"month":9,'
            '"location_id":"ff63f35a-ddd1-449e-9021-33ee78e2261a",'
            '"scheduling_enabled":true,"locked_month":false,'
            '"enabled_by":"2583717c-1d7a-4901-8788-a8096cfdf8e3",'
            '"enabled_at":"2026-08-15T12:00:00.000Z",'
            '"max_hours_per_day":18,"max_employees_per_shift":3}',
            200,
          );
        },
      ),
    );

    await repos.scheduling.setSchedulingEnabled(
      year: 2026,
      month: 9,
      location: 'Gara',
      enabled: true,
      adminUid: 'firebase-admin-1',
    );

    expect(requests.single.url.path, isNot('/api/scheduling/sched-global-sep'));
  });

  test('locks a month with PATCH on the exact config', () async {
    final requests = <http.Request>[];
    final repos = buildSchedulingRepos(
      schedulingApiMock(
        onWrite: (request) async {
          requests.add(request);
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/scheduling/sched-gara-sep');
          return http.Response(
            '{"id":"sched-gara-sep","year":2026,"month":9,'
            '"location_id":"ff63f35a-ddd1-449e-9021-33ee78e2261a",'
            '"scheduling_enabled":false,"locked_month":true,'
            '"enabled_by":"2583717c-1d7a-4901-8788-a8096cfdf8e3",'
            '"enabled_at":"2026-08-14T08:00:00.000Z",'
            '"max_hours_per_day":18,"max_employees_per_shift":3}',
            200,
          );
        },
      ),
    );

    await repos.scheduling.setMonthLocked(
      year: 2026,
      month: 9,
      location: 'Gara',
      locked: true,
    );

    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['locked_month'], isTrue);
    expect(body.containsKey('scheduling_enabled'), isFalse);
    expect(body.containsKey('enabled_by'), isFalse);
  });

  test('creates a lock config with POST when none exists', () async {
    final requests = <http.Request>[];
    final repos = buildSchedulingRepos(
      schedulingApiMock(
        onWrite: (request) async {
          requests.add(request);
          expect(request.method, 'POST');
          expect(request.url.path, '/api/scheduling');
          return http.Response(
            '{"id":"sched-lock-new","year":2026,"month":11,"location_id":null,'
            '"scheduling_enabled":false,"locked_month":true,'
            '"enabled_by":null,"enabled_at":null,'
            '"max_hours_per_day":null,"max_employees_per_shift":null}',
            201,
          );
        },
      ),
    );

    await repos.scheduling.setMonthLocked(
      year: 2026,
      month: 11,
      locked: true,
    );

    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['year'], 2026);
    expect(body['month'], 11);
    expect(body['locked_month'], isTrue);
    expect(body.containsKey('enabled_by'), isFalse);
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
      repos.scheduling.setSchedulingEnabled(
        year: 2026,
        month: 10,
        enabled: true,
        adminUid: 'firebase-admin-1',
      ),
      throwsA(
        isA<ApiHttpException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.errorCode, 'errorCode', 'forbidden'),
      ),
    );
  });

  test('scheduling UI and repository do not write Firestore', () {
    const files = [
      'lib/features/scheduling/data/scheduling_config_repository.dart',
      'lib/features/scheduling/domain/scheduling_config_model.dart',
      'lib/features/admin/presentation/open_scheduling_screen.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source.contains('cloud_firestore'), isFalse, reason: path);
      expect(source.contains('FirebaseFirestore'), isFalse, reason: path);
      expect(
        source.contains("collection('scheduling_config')"),
        isFalse,
        reason: path,
      );
      expect(source.contains('.set('), isFalse, reason: path);
      expect(source.contains('.update('), isFalse, reason: path);
    }

    final repo = File(
      'lib/features/scheduling/data/scheduling_config_repository.dart',
    ).readAsStringSync();
    expect(repo.contains('/api/scheduling'), isTrue);
    expect(repo.contains('postJson'), isTrue);
    expect(repo.contains('patchJson'), isTrue);

    final screen = File(
      'lib/features/admin/presentation/open_scheduling_screen.dart',
    ).readAsStringSync();
    expect(screen.contains('setSchedulingEnabled'), isTrue);
    expect(screen.contains('invalidate'), isTrue);

    final service = File(
      'lib/features/scheduling/data/scheduling_service.dart',
    ).readAsStringSync();
    expect(service.contains("collection('shifts')"), isFalse);
    expect(service.contains('cloud_firestore'), isFalse);
    expect(service.contains("collection('scheduling_config')"), isFalse);
  });
}
