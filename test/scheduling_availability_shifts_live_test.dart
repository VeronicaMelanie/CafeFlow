import 'dart:io';

import 'package:fivetogo_scheduler/core/api/api_client.dart';
import 'package:fivetogo_scheduler/core/api/api_exception.dart';
import 'package:fivetogo_scheduler/core/api/auth_token_source.dart';
import 'package:fivetogo_scheduler/features/auth/data/users_repository.dart';
import 'package:fivetogo_scheduler/features/locations/data/location_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/data/availability_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/data/scheduling_config_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/data/shift_repository.dart';
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

  test('invalid token returns 401 from scheduling, availability and shifts',
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
      SchedulingConfigRepository(
        apiClient: client,
        usersRepository: users,
        locationRepository: locations,
      ).listConfigs(),
      throwsA(isA<ApiHttpException>().having((e) => e.statusCode, 's', 401)),
    );
    await expectLater(
      AvailabilityRepository(
        apiClient: client,
        usersRepository: users,
      ).getAllAvailability(),
      throwsA(isA<ApiHttpException>().having((e) => e.statusCode, 's', 401)),
    );
    await expectLater(
      ShiftRepository(
        apiClient: client,
        usersRepository: users,
        locationRepository: locations,
      ).getAllShifts(),
      throwsA(isA<ApiHttpException>().having((e) => e.statusCode, 's', 401)),
    );
  });

  test('valid token reads live scheduling, availability and shifts', () async {
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
    final configs = await SchedulingConfigRepository(
      apiClient: client,
      usersRepository: users,
      locationRepository: locations,
    ).listConfigs();
    final availability = await AvailabilityRepository(
      apiClient: client,
      usersRepository: users,
    ).getAllAvailability();
    final shifts = await ShiftRepository(
      apiClient: client,
      usersRepository: users,
      locationRepository: locations,
    ).getAllShifts();

    expect(configs, isNotEmpty);
    expect(configs.every((c) => c.year > 0 && c.month >= 1 && c.month <= 12), isTrue);
    expect(
      configs.every(
        (c) => c.location == null || c.location == 'Gara' || c.location == 'Avantgarden',
      ),
      isTrue,
    );

    expect(availability, isNotEmpty);
    expect(availability.every((a) => a.userId.isNotEmpty), isTrue);
    expect(availability.every((a) => a.date.year > 0), isTrue);

    expect(shifts, isNotEmpty);
    expect(shifts.every((s) => s.userId.isNotEmpty), isTrue);
    expect(
      shifts.every((s) => s.location == 'Gara' || s.location == 'Avantgarden'),
      isTrue,
    );
  });
}
