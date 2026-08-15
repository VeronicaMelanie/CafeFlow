import 'dart:io';

import 'package:fivetogo_scheduler/core/api/api_client.dart';
import 'package:fivetogo_scheduler/core/api/api_exception.dart';
import 'package:fivetogo_scheduler/core/api/auth_token_source.dart';
import 'package:fivetogo_scheduler/features/auth/data/users_repository.dart';
import 'package:fivetogo_scheduler/features/locations/data/location_repository.dart';
import 'package:fivetogo_scheduler/features/products/data/product_repository.dart';
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
    await expectLater(
      LocationRepository(apiClient: client).getLocations(),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
    await expectLater(
      ProductRepository(apiClient: client).getProducts(),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
    await expectLater(
      UsersRepository(
        apiClient: client,
        locationRepository: LocationRepository(apiClient: client),
      ).getUsers(),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
  });

  test('invalid token returns 401 from locations, products and users', () async {
    final baseUrl = liveBaseUrl;
    if (baseUrl == null) {
      markTestSkipped('Backend API is not running');
      return;
    }

    final client = clientFor('not-a-real-firebase-id-token');
    await expectLater(
      LocationRepository(apiClient: client).getLocations(),
      throwsA(isA<ApiHttpException>().having((e) => e.statusCode, 's', 401)),
    );
    await expectLater(
      ProductRepository(apiClient: client).getProducts(),
      throwsA(isA<ApiHttpException>().having((e) => e.statusCode, 's', 401)),
    );
    await expectLater(
      UsersRepository(
        apiClient: client,
        locationRepository: LocationRepository(apiClient: client),
      ).getUsers(),
      throwsA(isA<ApiHttpException>().having((e) => e.statusCode, 's', 401)),
    );
  });

  test('valid token reads live locations, products and users', () async {
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
    final locations =
        await LocationRepository(apiClient: client).getLocations();
    final products = await ProductRepository(apiClient: client).getProducts();
    final users = await UsersRepository(
      apiClient: client,
      locationRepository: LocationRepository(apiClient: client),
    ).getUsers();

    expect(locations, isNotEmpty);
    expect(locations.every((l) => l.id.isNotEmpty), isTrue);
    expect(locations.every((l) => l.code.isNotEmpty), isTrue);
    expect(locations.every((l) => l.name.isNotEmpty), isTrue);
    expect(locations.every((l) => l.code != l.name), isTrue);

    expect(products, hasLength(8));
    expect(products.every((p) => p.id.isNotEmpty && p.name.isNotEmpty), isTrue);

    expect(users, isNotEmpty);
    expect(users.every((u) => u.uid.isNotEmpty), isTrue);
    expect(users.every((u) => u.postgresId != null), isTrue);
    expect(users.every((u) => u.uid != u.postgresId), isTrue);
  });
}
