import 'dart:convert';
import 'dart:io';

import 'package:fivetogo_scheduler/core/api/api_exception.dart';
import 'package:fivetogo_scheduler/features/auth/data/users_repository.dart';
import 'package:fivetogo_scheduler/features/locations/data/location_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/api_test_harness.dart';

const _locationsJson = '''
[
  {
    "id": "loc-gara",
    "code": "gara",
    "name": "Gara",
    "is_active": true,
    "opened_on": null,
    "closed_on": null
  },
  {
    "id": "loc-ag",
    "code": "avantgarden",
    "name": "Avantgarden",
    "is_active": true,
    "opened_on": null,
    "closed_on": null
  }
]
''';

const _usersJson = '''
[
  {
    "id": "cb3355e2-1bad-4826-8796-ca1734ce288a",
    "firebase_uid": "firebase-employee-1",
    "email": "employee@example.com",
    "name": "Veronica",
    "role": "employee",
    "contract_type": "full_time",
    "employment_started_on": "2025-06-30",
    "monthly_target_hours": 160,
    "needs_contract_type": false,
    "auth_provider": "google"
  },
  {
    "id": "2583717c-1d7a-4901-8788-a8096cfdf8e3",
    "firebase_uid": "firebase-admin-1",
    "email": "admin@example.com",
    "name": "Malina",
    "role": "admin",
    "contract_type": "part_time",
    "employment_started_on": null,
    "monthly_target_hours": 80,
    "needs_contract_type": true,
    "auth_provider": "email"
  }
]
''';

UsersRepository buildUsersRepository(MockClient httpClient) {
  final api = buildTestApiClient(httpClient: httpClient);
  return UsersRepository(
    apiClient: api,
    locationRepository: LocationRepository(apiClient: api),
  );
}

void main() {
  test('maps Firebase UID to firebase_uid and keeps PostgreSQL UUID separate',
      () async {
    final paths = <String>[];
    final repository = buildUsersRepository(
      MockClient((request) async {
        paths.add(request.url.path);
        expect(request.headers['Authorization'], 'Bearer firebase-id-token');
        if (request.url.path == '/api/locations') {
          return http.Response(_locationsJson, 200);
        }
        return http.Response(_usersJson, 200);
      }),
    );

    final users = await repository.getUsers();
    final employee = users.firstWhere((user) => user.role == 'employee');
    final admin = users.firstWhere((user) => user.role == 'admin');

    expect(paths, containsAll(['/api/users', '/api/locations']));
    expect(employee.uid, 'firebase-employee-1');
    expect(employee.postgresId, 'cb3355e2-1bad-4826-8796-ca1734ce288a');
    expect(employee.uid, isNot(employee.postgresId));
    expect(employee.email, 'employee@example.com');
    expect(employee.workType, 'Full-time');
    expect(employee.contractType, 'full_time');
    expect(employee.employmentDate, DateTime.parse('2025-06-30'));
    expect(employee.primaryLocation, 'Gara');
    expect(employee.secondaryLocation, 'Avantgarden');

    expect(admin.uid, 'firebase-admin-1');
    expect(admin.postgresId, '2583717c-1d7a-4901-8788-a8096cfdf8e3');
    expect(admin.workType, 'Part-time');
    expect(admin.needsContractType, isTrue);

    final found = await repository.findByFirebaseUid('firebase-admin-1');
    expect(found?.postgresId, admin.postgresId);
    expect(found?.uid, 'firebase-admin-1');

    final employees = await repository.getEmployees();
    expect(employees.map((user) => user.uid), ['firebase-employee-1']);
  });

  test('returns an empty list when the API has no users', () async {
    final repository = buildUsersRepository(
      MockClient((request) async {
        if (request.url.path == '/api/locations') {
          return http.Response(_locationsJson, 200);
        }
        return http.Response('[]', 200);
      }),
    );

    expect(await repository.getUsers(), isEmpty);
    expect(await repository.findByFirebaseUid('missing'), isNull);
  });

  test('propagates HTTP errors', () async {
    final repository = buildUsersRepository(
      jsonMock(500, '{"error":"internal_error"}'),
    );

    await expectLater(
      repository.getUsers(),
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
    final repository = UsersRepository(
      apiClient: api,
      locationRepository: LocationRepository(apiClient: api),
    );

    await expectLater(
      repository.getUsers(),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
    expect(calls, 0);
  });

  test('creates the authenticated profile with POST /api/users', () async {
    final requests = <http.Request>[];
    final repository = buildUsersRepository(
      MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/locations') {
          return http.Response(_locationsJson, 200);
        }
        expect(request.method, 'POST');
        expect(request.url.path, '/api/users');
        expect(request.headers['Authorization'], 'Bearer firebase-id-token');
        expect(request.body.contains('firebase_uid'), isFalse);
        expect(request.body, contains('"name":"Write Profile Employee"'));
        return http.Response(
          jsonEncode({
            'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            'firebase_uid': 'firebase-new-user',
            'email': 'new@example.com',
            'name': 'Write Profile Employee',
            'role': 'employee',
            'contract_type': null,
            'employment_started_on': null,
            'monthly_target_hours': 160,
            'needs_contract_type': true,
            'auth_provider': 'google',
          }),
          201,
        );
      }),
    );

    final user = await repository.ensureCurrentUser(name: 'Write Profile Employee');
    expect(user.uid, 'firebase-new-user');
    expect(user.postgresId, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    expect(user.uid, isNot(user.postgresId));
    expect(user.needsContractType, isTrue);
    expect(user.contractType, isNull);
    expect(user.primaryLocation, 'Gara');
    expect(requests.any((r) => r.method == 'POST'), isTrue);
  });

  test('sets contract type with PATCH using the PostgreSQL UUID', () async {
    final requests = <http.Request>[];
    final repository = buildUsersRepository(
      MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/locations') {
          return http.Response(_locationsJson, 200);
        }
        if (request.method == 'GET' && request.url.path == '/api/users') {
          return http.Response(_usersJson, 200);
        }
        expect(request.method, 'PATCH');
        expect(
          request.url.path,
          '/api/users/cb3355e2-1bad-4826-8796-ca1734ce288a',
        );
        expect(request.body, contains('"contract_type":"part_time"'));
        expect(request.body, contains('"needs_contract_type":false'));
        return http.Response(
          jsonEncode({
            'id': 'cb3355e2-1bad-4826-8796-ca1734ce288a',
            'firebase_uid': 'firebase-employee-1',
            'email': 'employee@example.com',
            'name': 'Veronica',
            'role': 'employee',
            'contract_type': 'part_time',
            'employment_started_on': '2025-06-30',
            'monthly_target_hours': 160,
            'needs_contract_type': false,
            'auth_provider': 'google',
          }),
          200,
        );
      }),
    );

    await repository.setContractType(
      firebaseUid: 'firebase-employee-1',
      contractType: 'part_time',
    );

    final patch = requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.url.path.contains('firebase-employee-1'), isFalse);
  });

  test('admin employee update sends PostgreSQL profile fields as DATE', () async {
    final requests = <http.Request>[];
    final repository = buildUsersRepository(
      MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/locations') {
          return http.Response(_locationsJson, 200);
        }
        expect(request.method, 'PATCH');
        expect(
          request.url.path,
          '/api/users/cb3355e2-1bad-4826-8796-ca1734ce288a',
        );
        return http.Response(
          jsonEncode({
            'id': 'cb3355e2-1bad-4826-8796-ca1734ce288a',
            'firebase_uid': 'firebase-employee-1',
            'email': 'employee@example.com',
            'name': 'Edited Employee',
            'role': 'employee',
            'contract_type': 'part_time',
            'employment_started_on': '2099-08-15',
            'monthly_target_hours': 80,
            'needs_contract_type': false,
            'auth_provider': 'google',
          }),
          200,
        );
      }),
    );

    final updated = await repository.updateUser(
      postgresId: 'cb3355e2-1bad-4826-8796-ca1734ce288a',
      name: 'Edited Employee',
      monthlyTargetHours: 80,
      contractType: 'part_time',
      employmentDate: DateTime(2099, 8, 15, 22, 0),
    );

    expect(updated.name, 'Edited Employee');
    expect(updated.workType, 'Part-time');
    expect(updated.employmentDate, DateTime(2099, 8, 15));
    final patch = requests.singleWhere((request) => request.method == 'PATCH');
    expect(patch.body, contains('"name":"Edited Employee"'));
    expect(patch.body, contains('"monthly_target_hours":80'));
    expect(patch.body, contains('"contract_type":"part_time"'));
    expect(patch.body, contains('"employment_started_on":"2099-08-15"'));
    expect(patch.body.contains('primaryLocation'), isFalse);
    expect(patch.body.contains('fcm_token'), isFalse);
  });

  test('propagates profile write HTTP errors', () async {
    final repository = buildUsersRepository(
      MockClient((request) async {
        if (request.url.path == '/api/locations') {
          return http.Response(_locationsJson, 200);
        }
        if (request.method == 'POST') {
          return http.Response('{"error":"forbidden"}', 403);
        }
        return http.Response('{"error":"invalid_user"}', 400);
      }),
    );

    await expectLater(
      repository.ensureCurrentUser(name: 'Nope'),
      throwsA(
        isA<ApiHttpException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.errorCode, 'errorCode', 'forbidden'),
      ),
    );

    await expectLater(
      repository.updateUser(
        postgresId: 'cb3355e2-1bad-4826-8796-ca1734ce288a',
        contractType: 'nope',
      ),
      throwsA(
        isA<ApiHttpException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.errorCode, 'errorCode', 'invalid_user'),
      ),
    );
  });

  test('profile business writes use the API; FCM and notifications stay Firebase',
      () {
    final usersRepo = File(
      'lib/features/auth/data/users_repository.dart',
    ).readAsStringSync();
    expect(usersRepo.contains('/api/users'), isTrue);
    expect(usersRepo.contains('postJson'), isTrue);
    expect(usersRepo.contains('patchJson'), isTrue);
    expect(usersRepo.contains('cloud_firestore'), isFalse);

    final auth = File(
      'lib/features/auth/data/auth_repository.dart',
    ).readAsStringSync();
    expect(auth.contains('signInWithGoogle'), isTrue);
    expect(auth.contains('signInWithEmail'), isTrue);
    expect(auth.contains('FirebaseAuth'), isTrue);
    expect(auth.contains('GoogleSignIn'), isTrue);
    expect(auth.contains("collection('notifications')"), isTrue);
    expect(auth.contains("collection('users')"), isTrue);
    expect(auth.contains("'needsContractType': false"), isFalse);
    expect(auth.contains('ensureCurrentUser'), isTrue);
    expect(auth.contains('_ensureUserProfileDocument'), isTrue);

    final employees = File(
      'lib/features/admin/presentation/employee_management_screen.dart',
    ).readAsStringSync();
    expect(employees.contains('cloud_firestore'), isFalse);
    expect(employees.contains("collection('users')"), isFalse);
    expect(employees.contains('updateUser'), isTrue);
    expect(employees.contains('usersRepositoryProvider'), isTrue);

    final fcm = File('lib/core/services/fcm_service.dart').readAsStringSync();
    expect(fcm.contains("collection('users')"), isTrue);
    expect(fcm.contains('fcmToken'), isTrue);

    final options = File('lib/firebase_options.dart').readAsStringSync();
    expect(options.contains('FirebaseOptions'), isTrue);
  });
}
