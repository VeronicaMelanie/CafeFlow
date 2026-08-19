import 'dart:io';

import 'package:fivetogo_scheduler/core/api/api_exception.dart';
import 'package:fivetogo_scheduler/features/auth/data/users_repository.dart';
import 'package:fivetogo_scheduler/features/consumption/data/consumption_repository.dart';
import 'package:fivetogo_scheduler/features/consumption/domain/consumption_model.dart';
import 'package:fivetogo_scheduler/features/locations/data/location_repository.dart';
import 'package:fivetogo_scheduler/features/products/data/product_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/api_test_harness.dart';
import 'helpers/vcc_api_fixtures.dart';

void main() {
  test('maps GET /api/consumptions JSON with UID, product name, and DATE', () {
    const json = {
      'id': 'cons-1',
      'user_id': 'cb3355e2-1bad-4826-8796-ca1734ce288a',
      'product_id': 'prod-coffee',
      'location_id': 'ff63f35a-ddd1-449e-9021-33ee78e2261a',
      'quantity': 2,
      'consumed_on': '2026-08-13',
      'logged_at': '2026-08-13T09:15:00.000Z',
      'notes': 'after shift',
    };

    final model = ConsumptionModel.fromApiJson(
      json,
      firebaseUid: 'firebase-employee-1',
      productName: 'Espresso',
    );

    expect(model.userId, 'firebase-employee-1');
    expect(model.productName, 'Espresso');
    expect(model.productName, isNot('prod-coffee'));
    expect(model.quantity, 2);
    expect(model.date, DateTime(2026, 8, 13));
    expect(model.date.isUtc, isFalse);
    expect(model.loggedAt, DateTime.utc(2026, 8, 13, 9, 15).toLocal());
    expect(model.displayDateTime.hour, DateTime.utc(2026, 8, 13, 9, 15).toLocal().hour);
    expect(model.displayDateTime.minute, 15);
    expect(model.notes, 'after shift');
  });

  test('empty PostgreSQL response is a valid empty list', () async {
    final paths = <String>[];
    final repos = buildVccRepos(
      vccApiMock(consumptions: '[]', capturedPaths: paths),
    );

    final all = await repos.consumptions.getAllConsumptionsUnfiltered();
    expect(paths, contains('/api/consumptions'));
    expect(all, isEmpty);
    expect(
      await repos.consumptions
          .getConsumptionsForUser('firebase-employee-1')
          .first,
      isEmpty,
    );
    expect(
      await repos.consumptions
          .getUserConsumptions('firebase-employee-1', DateTime(2026, 8, 1))
          .first,
      isEmpty,
    );
  });

  test('maps product name and filters by user and month', () async {
    final repos = buildVccRepos(
      vccApiMock(consumptions: consumptionsOneJson),
    );

    final all = await repos.consumptions.getAllConsumptionsUnfiltered();
    expect(all.map((c) => c.id), ['cons-1', 'cons-other-month']);
    expect(all.every((c) => c.productName == 'Espresso'), isTrue);
    expect(all.every((c) => c.userId == 'firebase-employee-1'), isTrue);

    final august = await repos.consumptions
        .getUserConsumptions('firebase-employee-1', DateTime(2026, 8, 1))
        .first;
    expect(august.map((c) => c.id), ['cons-1']);

    final history = await repos.consumptions
        .getConsumptionsForUser('firebase-employee-1')
        .first;
    expect(history.map((c) => c.id), ['cons-1', 'cons-other-month']);
  });

  test('test mode writes do not require Firestore', () async {
    final repository = ConsumptionRepository.test();
    await repository.addConsumption(
      ConsumptionModel(
        id: '',
        userId: 'firebase-employee-1',
        productName: 'Espresso',
        quantity: 1,
        date: DateTime(2026, 8, 13),
      ),
    );
    await repository.updateConsumption('id', 'Espresso', 2, '');
    await repository.deleteConsumption('id');
    expect(await repository.getAllConsumptionsUnfiltered(), isEmpty);
  });

  test('propagates HTTP errors', () async {
    final repos = buildVccRepos(vccApiMock(statusCode: 500));
    await expectLater(
      repos.consumptions.getAllConsumptionsUnfiltered(),
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
    final repository = ConsumptionRepository(
      apiClient: api,
      usersRepository: UsersRepository(
        apiClient: api,
        locationRepository: LocationRepository(apiClient: api),
      ),
      productRepository: ProductRepository(apiClient: api),
    );

    await expectLater(
      repository.getAllConsumptionsUnfiltered(),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
    expect(calls, 0);
  });

  test('creates a consumption with POST product_name and DATE, no user_id',
      () async {
    final requests = <http.Request>[];
    final repos = buildVccRepos(
      vccApiMock(
        onWrite: (request) async {
          requests.add(request);
          expect(request.method, 'POST');
          expect(request.url.path, '/api/consumptions');
          return http.Response(
            '{"id":"cons-new","user_id":"cb3355e2-1bad-4826-8796-ca1734ce288a",'
            '"product_id":"prod-coffee","product_name":"Espresso",'
            '"location_id":"ff63f35a-ddd1-449e-9021-33ee78e2261a",'
            '"quantity":2,"consumed_on":"2026-11-02","logged_at":"2026-08-15T12:00:00.000Z",'
            '"notes":"after shift"}',
            201,
          );
        },
      ),
    );

    await repos.consumptions.addConsumption(
      ConsumptionModel(
        id: '',
        userId: 'firebase-employee-1',
        productName: 'Espresso',
        quantity: 2,
        date: DateTime(2026, 11, 2, 22, 15),
        notes: 'after shift',
      ),
    );

    expect(requests, hasLength(1));
    expect(requests.single.body, contains('"product_name":"Espresso"'));
    expect(requests.single.body, contains('"consumed_on":"2026-11-02"'));
    expect(requests.single.body, contains('"quantity":2'));
    expect(requests.single.body, contains('"notes":"after shift"'));
    expect(requests.single.body.contains('user_id'), isFalse);
    expect(requests.single.body.contains('productName'), isFalse);
  });

  test('posts typed product_name when the catalog has no match', () async {
    final requests = <http.Request>[];
    final repos = buildVccRepos(
      vccApiMock(
        onWrite: (request) async {
          requests.add(request);
          return http.Response(
            '{"id":"cons-new","user_id":"cb3355e2-1bad-4826-8796-ca1734ce288a",'
            '"product_id":"prod-new","product_name":"ceai verde",'
            '"location_id":"ff63f35a-ddd1-449e-9021-33ee78e2261a",'
            '"quantity":1,"consumed_on":"2026-11-02","logged_at":"2026-08-15T12:00:00.000Z",'
            '"notes":null}',
            201,
          );
        },
      ),
    );

    await repos.consumptions.addConsumption(
      ConsumptionModel(
        id: '',
        userId: 'firebase-employee-1',
        productName: 'ceai verde',
        quantity: 1,
        date: DateTime(2026, 11, 2),
      ),
    );

    expect(requests.single.body, contains('"product_name":"ceai verde"'));
    expect(requests.single.body.contains('product_id'), isFalse);
  });

  test('updates and deletes through PATCH/DELETE with PostgreSQL UUID',
      () async {
    final requests = <http.Request>[];
    final repos = buildVccRepos(
      vccApiMock(
        onWrite: (request) async {
          requests.add(request);
          if (request.method == 'DELETE') {
            return http.Response('', 204);
          }
          return http.Response(
            '{"id":"cons-1","user_id":"cb3355e2-1bad-4826-8796-ca1734ce288a",'
            '"product_id":"prod-coffee","location_id":"ff63f35a-ddd1-449e-9021-33ee78e2261a",'
            '"quantity":4,"consumed_on":"2026-08-13","logged_at":"2026-08-13T09:15:00.000Z",'
            '"notes":"updated"}',
            200,
          );
        },
      ),
    );

    await repos.consumptions.updateConsumption('cons-1', 'Espresso', 4, 'updated');
    expect(requests.single.method, 'PATCH');
    expect(requests.single.url.path, '/api/consumptions/cons-1');
    expect(requests.single.body, contains('"product_name":"Espresso"'));
    expect(requests.single.body, contains('"quantity":4'));
    expect(requests.single.body, contains('"notes":"updated"'));
    expect(requests.single.body.contains('productName'), isFalse);

    requests.clear();
    await repos.consumptions.deleteConsumption('cons-1');
    expect(requests.single.method, 'DELETE');
    expect(requests.single.url.path, '/api/consumptions/cons-1');
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
      repos.consumptions.addConsumption(
        ConsumptionModel(
          id: '',
          userId: 'firebase-employee-1',
          productName: 'Espresso',
          quantity: 1,
          date: DateTime(2026, 11, 2),
        ),
      ),
      throwsA(
        isA<ApiHttpException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.errorCode, 'errorCode', 'forbidden'),
      ),
    );
  });

  test('consumption UI and repository do not write Firestore', () {
    const files = [
      'lib/features/consumption/data/consumption_repository.dart',
      'lib/features/consumption/domain/consumption_model.dart',
      'lib/features/consumption/presentation/consumption_entry_screen.dart',
      'lib/features/admin/presentation/consumption_log_screen.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source.contains('cloud_firestore'), isFalse, reason: path);
      expect(source.contains('FirebaseFirestore'), isFalse, reason: path);
      expect(
        source.contains("collection('consumptions')"),
        isFalse,
        reason: path,
      );
    }

    final entry = File(
      'lib/features/consumption/presentation/consumption_entry_screen.dart',
    ).readAsStringSync();
    expect(entry.contains('addConsumption'), isTrue);
    expect(entry.contains('updateConsumption'), isTrue);
    expect(entry.contains('deleteConsumption'), isTrue);
  });
}
