import 'dart:io';

import 'package:fivetogo_scheduler/core/api/api_datetime.dart';
import 'package:fivetogo_scheduler/core/api/api_exception.dart';
import 'package:fivetogo_scheduler/features/auth/data/users_repository.dart';
import 'package:fivetogo_scheduler/features/locations/data/location_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/data/vacation_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/domain/vacation_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/api_test_harness.dart';
import 'helpers/vcc_api_fixtures.dart';

void main() {
  test('maps GET /api/vacations JSON with UID, DATE, and timestamptz', () {
    const json = {
      'id': 'vac-approved',
      'user_id': 'cb3355e2-1bad-4826-8796-ca1734ce288a',
      'start_on': '2026-08-26',
      'end_on': '2026-08-29',
      'status': 'approved',
      'admin_comment': null,
      'requested_at': '2026-07-16T15:00:33.092Z',
    };

    final model = VacationModel.fromApiJson(
      json,
      firebaseUid: 'firebase-employee-1',
      userName: 'Veronica',
    );

    expect(model.userId, 'firebase-employee-1');
    expect(model.userId, isNot('cb3355e2-1bad-4826-8796-ca1734ce288a'));
    expect(model.userName, 'Veronica');
    expect(model.startDate, DateTime(2026, 8, 26));
    expect(model.endDate, DateTime(2026, 8, 29));
    expect(model.startDate.isUtc, isFalse);
    expect(model.status, 'approved');
    expect(model.adminComment, isNull);
    expect(model.durationInDays, 4);
    expect(
      model.requestedAt.toUtc(),
      DateTime.parse('2026-07-16T15:00:33.092Z').toUtc(),
    );
  });

  test('filters by user and pending status and sorts newest requested first',
      () async {
    final paths = <String>[];
    final repos = buildVccRepos(vccApiMock(capturedPaths: paths));

    final forUser = await repos.vacations
        .getVacationsForUser('firebase-employee-1')
        .first;
    expect(paths, contains('/api/vacations'));
    expect(
      forUser.map((v) => v.id),
      ['vac-pending-new', 'vac-approved', 'vac-rejected'],
    );
    expect(forUser.every((v) => v.userId == 'firebase-employee-1'), isTrue);
    expect(forUser.any((v) => v.id == 'vac-unknown-user'), isFalse);

    final pending = await repos.vacations.getAllPendingVacations().first;
    expect(pending.map((v) => v.id), ['vac-pending-new', 'vac-admin-pending']);
    expect(pending.every((v) => v.status == 'pending'), isTrue);
    expect(pending.first.adminComment, 'Need coverage');
    expect(pending.last.userId, 'firebase-admin-1');
  });

  test('returns an empty list when the API has no vacations', () async {
    final repos = buildVccRepos(vccApiMock(vacations: '[]'));
    expect(await repos.vacations.getAllVacations(), isEmpty);
    expect(
      await repos.vacations.getVacationsForUser('firebase-employee-1').first,
      isEmpty,
    );
  });

  test('test mode reads and writes do not call the API', () async {
    final repository = VacationRepository.test();
    expect(await repository.getAllVacations(), isEmpty);
    await repository.requestVacation(
      VacationModel(
        id: '',
        userId: 'firebase-employee-1',
        userName: 'Veronica',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 2),
        status: 'pending',
        requestedAt: DateTime(2026, 8, 1),
      ),
    );
    await repository.updateVacationStatus(
      VacationModel(
        id: 'vac-1',
        userId: 'firebase-employee-1',
        userName: 'Veronica',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 2),
        status: 'pending',
        requestedAt: DateTime(2026, 8, 1),
      ),
      'approved',
    );
  });

  test('propagates HTTP errors', () async {
    final repos = buildVccRepos(vccApiMock(statusCode: 500));
    await expectLater(
      repos.vacations.getAllVacations(),
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
    final repository = VacationRepository(
      apiClient: api,
      usersRepository: UsersRepository(
        apiClient: api,
        locationRepository: LocationRepository(apiClient: api),
      ),
    );

    await expectLater(
      repository.getAllVacations(),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
    expect(calls, 0);
  });

  test('DATE mapping does not use UTC midnight', () {
    final date = ApiDateTime.parseDateOnly('2026-08-26');
    expect(date, DateTime(2026, 8, 26));
    expect(date.isUtc, isFalse);
  });

  test('creates a vacation with POST DATE fields and no user_id', () async {
    final requests = <http.Request>[];
    final repos = buildVccRepos(
      vccApiMock(
        onWrite: (request) async {
          requests.add(request);
          expect(request.method, 'POST');
          expect(request.url.path, '/api/vacations');
          return http.Response(
            '{"id":"vac-new","user_id":"cb3355e2-1bad-4826-8796-ca1734ce288a",'
            '"start_on":"2026-11-02","end_on":"2026-11-05","status":"pending",'
            '"admin_comment":null,"requested_at":"2026-08-15T12:00:00.000Z"}',
            201,
          );
        },
      ),
    );

    await repos.vacations.requestVacation(
      VacationModel(
        id: '',
        userId: 'firebase-employee-1',
        userName: 'Veronica',
        startDate: DateTime(2026, 11, 2, 22, 15),
        endDate: DateTime(2026, 11, 5, 8, 0),
        status: 'pending',
        requestedAt: DateTime(2026, 8, 15),
      ),
    );

    expect(requests, hasLength(1));
    expect(requests.single.body, contains('"start_on":"2026-11-02"'));
    expect(requests.single.body, contains('"end_on":"2026-11-05"'));
    expect(requests.single.body.contains('user_id'), isFalse);
    expect(requests.single.body.contains('status'), isFalse);
  });

  test('approves and rejects through PATCH with PostgreSQL UUID', () async {
    final requests = <http.Request>[];
    final repos = buildVccRepos(
      vccApiMock(
        onWrite: (request) async {
          requests.add(request);
          return http.Response(
            '{"id":"vac-pending-new","user_id":"cb3355e2-1bad-4826-8796-ca1734ce288a",'
            '"start_on":"2026-09-16","end_on":"2026-09-21","status":"approved",'
            '"admin_comment":"Covered","requested_at":"2026-08-14T07:26:15.347Z"}',
            200,
          );
        },
      ),
    );

    final vacation = VacationModel(
      id: 'vac-pending-new',
      userId: 'firebase-employee-1',
      userName: 'Veronica',
      startDate: DateTime(2026, 9, 16),
      endDate: DateTime(2026, 9, 21),
      status: 'pending',
      requestedAt: DateTime(2026, 8, 14),
    );

    await repos.vacations.updateVacationStatus(vacation, 'approved');
    expect(requests.single.method, 'PATCH');
    expect(requests.single.url.path, '/api/vacations/vac-pending-new');
    expect(requests.single.body, contains('"status":"approved"'));
    expect(requests.single.body.contains('admin_comment'), isFalse);

    requests.clear();
    await repos.vacations.updateVacationStatus(
      vacation,
      'rejected',
      comment: 'Need coverage',
    );
    expect(requests.single.url.path, '/api/vacations/vac-pending-new');
    expect(requests.single.body, contains('"status":"rejected"'));
    expect(requests.single.body, contains('"admin_comment":"Need coverage"'));
  });

  test('propagates write HTTP errors instead of treating them as success',
      () async {
    final repos = buildVccRepos(
      vccApiMock(
        onWrite: (request) async {
          return http.Response('{"error":"forbidden"}', 403);
        },
      ),
    );

    await expectLater(
      repos.vacations.updateVacationStatus(
        VacationModel(
          id: 'vac-pending-new',
          userId: 'firebase-employee-1',
          userName: 'Veronica',
          startDate: DateTime(2026, 9, 16),
          endDate: DateTime(2026, 9, 21),
          status: 'pending',
          requestedAt: DateTime(2026, 8, 14),
        ),
        'approved',
      ),
      throwsA(
        isA<ApiHttpException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.errorCode, 'errorCode', 'forbidden'),
      ),
    );
  });

  test('vacation UI and repository do not write Firestore', () {
    const files = [
      'lib/features/scheduling/data/vacation_repository.dart',
      'lib/features/scheduling/presentation/vacation_request_screen.dart',
      'lib/features/admin/presentation/vacation_approval_screen.dart',
      'lib/features/scheduling/presentation/vacation_status_screen.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source.contains('cloud_firestore'), isFalse, reason: path);
      expect(source.contains('FirebaseFirestore'), isFalse, reason: path);
      expect(source.contains("collection('vacations')"), isFalse, reason: path);
    }

    final request = File(
      'lib/features/scheduling/presentation/vacation_request_screen.dart',
    ).readAsStringSync();
    expect(request.contains('requestVacation'), isTrue);

    final approval = File(
      'lib/features/admin/presentation/vacation_approval_screen.dart',
    ).readAsStringSync();
    expect(approval.contains('updateVacationStatus'), isTrue);
  });
}
