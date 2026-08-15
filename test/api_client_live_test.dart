import 'dart:io';

import 'package:fivetogo_scheduler/core/api/api_client.dart';
import 'package:fivetogo_scheduler/core/api/api_exception.dart';
import 'package:fivetogo_scheduler/core/api/auth_token_source.dart';
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

  setUpAll(() async {
    liveBaseUrl = await detectLiveBaseUrl();
  });

  test('GET /health against the running PostgreSQL API', () async {
    final baseUrl = liveBaseUrl;
    if (baseUrl == null) {
      markTestSkipped('Backend API is not running on 127.0.0.1:3007/3006/3000');
      return;
    }

    final client = ApiClient(
      tokenSource: FakeTokenSource(null),
      baseUrl: baseUrl,
    );
    addTearDown(client.close);

    final json = await client.getJson('/health', requireAuth: false) as Map;
    expect(json['status'], 'ok');
    expect(json['database'], 'connected');
  });

  test('GET /api/auth/me without a Firebase user is rejected locally', () async {
    final client = ApiClient(
      tokenSource: FakeTokenSource(null),
      baseUrl: liveBaseUrl ?? 'http://127.0.0.1:3000',
    );
    addTearDown(client.close);

    await expectLater(
      client.get('/api/auth/me'),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
  });

  test('GET /api/auth/me with an invalid token hits the real API 401 path',
      () async {
    final baseUrl = liveBaseUrl;
    if (baseUrl == null) {
      markTestSkipped('Backend API is not running on 127.0.0.1:3007/3006/3000');
      return;
    }

    final client = ApiClient(
      tokenSource: FakeTokenSource('not-a-real-firebase-id-token'),
      baseUrl: baseUrl,
    );
    addTearDown(client.close);

    await expectLater(
      client.get('/api/auth/me'),
      throwsA(
        isA<ApiHttpException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.errorCode, 'errorCode', 'unauthorized'),
      ),
    );
  });
}
