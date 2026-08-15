import 'dart:io';

import 'package:fivetogo_scheduler/core/api/api_client.dart';
import 'package:fivetogo_scheduler/core/api/api_exception.dart';
import 'package:fivetogo_scheduler/core/api/auth_token_source.dart';
import 'package:fivetogo_scheduler/features/auth/data/users_repository.dart';
import 'package:fivetogo_scheduler/features/cleaning/data/cleaning_repository.dart';
import 'package:fivetogo_scheduler/features/cleaning/domain/cleaning_list_key.dart';
import 'package:fivetogo_scheduler/features/consumption/data/consumption_repository.dart';
import 'package:fivetogo_scheduler/features/locations/data/location_repository.dart';
import 'package:fivetogo_scheduler/features/products/data/product_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/data/vacation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class FakeTokenSource implements AuthTokenSource {
  FakeTokenSource(this.token);
  final String? token;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => token;
}

Future<String?> detectLiveBaseUrl() async {
  const candidates = [
    'http://127.0.0.1:3007',
    'http://127.0.0.1:3006',
    'http://127.0.0.1:3000',
  ];
  for (final base in candidates) {
    try {
      final response = await http
          .get(Uri.parse('$base/health'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) return base;
    } on SocketException {
      continue;
    } catch (_) {
      continue;
    }
  }
  return null;
}

void main() {
  late String? liveBaseUrl;
  late String? liveToken;

  setUpAll(() async {
    liveBaseUrl = await detectLiveBaseUrl();
    liveToken = Platform.environment['FIREBASE_ID_TOKEN'];
    if (liveToken != null && liveToken!.isEmpty) {
      liveToken = null;
    }
  });

  ApiClient clientFor(String? token) {
    final client = ApiClient(
      tokenSource: FakeTokenSource(token),
      baseUrl: liveBaseUrl ?? 'http://127.0.0.1:3000',
    );
    addTearDown(client.close);
    return client;
  }

  test('unauthenticated reads are rejected by ApiClient', () async {
    final client = clientFor(null);
    final locations = LocationRepository(apiClient: client);
    final users = UsersRepository(
      apiClient: client,
      locationRepository: locations,
    );
    await expectLater(
      VacationRepository(apiClient: client, usersRepository: users)
          .getAllVacations(),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
    await expectLater(
      CleaningRepository(
        apiClient: client,
        usersRepository: users,
        locationRepository: locations,
      ).watchTasksForList('Gara_closing').first,
      throwsA(isA<ApiUnauthenticatedException>()),
    );
    await expectLater(
      ConsumptionRepository(
        apiClient: client,
        usersRepository: users,
        productRepository: ProductRepository(apiClient: client),
      ).getAllConsumptionsUnfiltered(),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
    await expectLater(
      ProductRepository(apiClient: client).getProducts(),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
  });

  test('invalid token returns 401 from vacations, cleaning, consumptions, products',
      () async {
    final baseUrl = liveBaseUrl;
    if (baseUrl == null) {
      markTestSkipped('Backend API is not running');
      return;
    }

    final client = clientFor('not-a-real-firebase-id-token');
    final locations = LocationRepository(apiClient: client);
    final users = UsersRepository(
      apiClient: client,
      locationRepository: locations,
    );

    await expectLater(
      VacationRepository(apiClient: client, usersRepository: users)
          .getAllVacations(),
      throwsA(isA<ApiHttpException>().having((e) => e.statusCode, 's', 401)),
    );
    await expectLater(
      CleaningRepository(
        apiClient: client,
        usersRepository: users,
        locationRepository: locations,
      ).watchTasksForList('Gara_closing').first,
      throwsA(isA<ApiHttpException>().having((e) => e.statusCode, 's', 401)),
    );
    await expectLater(
      ConsumptionRepository(
        apiClient: client,
        usersRepository: users,
        productRepository: ProductRepository(apiClient: client),
      ).getAllConsumptionsUnfiltered(),
      throwsA(isA<ApiHttpException>().having((e) => e.statusCode, 's', 401)),
    );
    await expectLater(
      ProductRepository(apiClient: client).getProducts(),
      throwsA(isA<ApiHttpException>().having((e) => e.statusCode, 's', 401)),
    );
  });

  test('valid token reads live vacations, cleaning, consumptions and products',
      () async {
    final baseUrl = liveBaseUrl;
    final token = liveToken;
    if (baseUrl == null) {
      markTestSkipped('Backend API is not running');
      return;
    }
    if (token == null) {
      markTestSkipped('FIREBASE_ID_TOKEN is not set');
      return;
    }

    final client = clientFor(token);
    final locations = LocationRepository(apiClient: client);
    final users = UsersRepository(
      apiClient: client,
      locationRepository: locations,
    );
    final vacations = await VacationRepository(
      apiClient: client,
      usersRepository: users,
    ).getAllVacations();
    final cleaningTasks = await CleaningRepository(
      apiClient: client,
      usersRepository: users,
      locationRepository: locations,
    )
        .watchTasksForList(
          CleaningListKey.listId('Gara', CleaningListKey.closing),
        )
        .first;
    final consumptions = await ConsumptionRepository(
      apiClient: client,
      usersRepository: users,
      productRepository: ProductRepository(apiClient: client),
    ).getAllConsumptionsUnfiltered();
    final products = await ProductRepository(apiClient: client).getProducts();

    expect(vacations, isNotEmpty);
    expect(vacations.every((v) => v.userId.isNotEmpty), isTrue);
    expect(vacations.every((v) => v.startDate.isUtc == false), isTrue);

    expect(cleaningTasks.every((t) => t.location == 'Gara'), isTrue);
    expect(
      cleaningTasks.every(
        (t) => t.listId == CleaningListKey.listId('Gara', CleaningListKey.closing),
      ),
      isTrue,
    );

    expect(consumptions, isEmpty);

    expect(products, hasLength(8));
  });
}
