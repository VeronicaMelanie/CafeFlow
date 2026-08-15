import 'package:fivetogo_scheduler/core/api/api_client.dart';
import 'package:fivetogo_scheduler/core/api/api_config.dart';
import 'package:fivetogo_scheduler/core/api/api_exception.dart';
import 'package:fivetogo_scheduler/core/api/auth_token_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeTokenSource implements AuthTokenSource {
  FakeTokenSource(this._tokens);

  final List<String?> _tokens;
  final List<bool> forceRefreshCalls = [];

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    forceRefreshCalls.add(forceRefresh);
    if (forceRefreshCalls.length > _tokens.length) {
      return _tokens.last;
    }
    return _tokens[forceRefreshCalls.length - 1];
  }
}

ApiClient buildClient({
  required AuthTokenSource tokenSource,
  required MockClient httpClient,
  String baseUrl = 'http://127.0.0.1:3000',
}) {
  return ApiClient(
    tokenSource: tokenSource,
    httpClient: httpClient,
    baseUrl: baseUrl,
  );
}

void main() {
  tearDown(() {
    ApiConfig.debugOverride = null;
  });

  test('attaches Firebase ID token as Authorization Bearer header', () async {
    http.Request? captured;
    final client = buildClient(
      tokenSource: FakeTokenSource(['firebase-id-token']),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response('{"authenticated":true}', 200);
      }),
    );

    final response = await client.get('/api/auth/me');

    expect(response.statusCode, 200);
    expect(captured, isNotNull);
    expect(captured!.headers['Authorization'], 'Bearer firebase-id-token');
    expect(captured!.url.path, '/api/auth/me');
  });

  test('does not send a request when no user is signed in', () async {
    var httpCalls = 0;
    final client = buildClient(
      tokenSource: FakeTokenSource([null]),
      httpClient: MockClient((request) async {
        httpCalls += 1;
        return http.Response('should-not-run', 200);
      }),
    );

    await expectLater(
      client.get('/api/users'),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
    expect(httpCalls, 0);
  });

  test('401 forces ID token refresh and retries once', () async {
    final requests = <http.Request>[];
    final tokens = FakeTokenSource(['stale-token', 'fresh-token']);
    final client = buildClient(
      tokenSource: tokens,
      httpClient: MockClient((request) async {
        requests.add(request);
        final auth = request.headers['Authorization'];
        if (auth == 'Bearer stale-token') {
          return http.Response('{"error":"unauthorized"}', 401);
        }
        if (auth == 'Bearer fresh-token') {
          return http.Response(
            '{"authenticated":true,"uid":"firebase-uid"}',
            200,
          );
        }
        return http.Response('{"error":"unexpected"}', 500);
      }),
    );

    final response = await client.get('/api/auth/me');

    expect(response.statusCode, 200);
    expect(requests, hasLength(2));
    expect(requests[0].headers['Authorization'], 'Bearer stale-token');
    expect(requests[1].headers['Authorization'], 'Bearer fresh-token');
    expect(tokens.forceRefreshCalls, [false, true]);
  });

  test('401 after refresh is propagated as an HTTP error', () async {
    final tokens = FakeTokenSource(['stale-token', 'still-stale']);
    final client = buildClient(
      tokenSource: tokens,
      httpClient: MockClient((request) async {
        return http.Response('{"error":"unauthorized"}', 401);
      }),
    );

    await expectLater(
      client.get('/api/auth/me'),
      throwsA(
        isA<ApiHttpException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.errorCode, 'errorCode', 'unauthorized'),
      ),
    );
    expect(tokens.forceRefreshCalls, [false, true]);
  });

  test('non-401 HTTP errors are propagated without a token refresh', () async {
    final tokens = FakeTokenSource(['firebase-id-token']);
    var httpCalls = 0;
    final client = buildClient(
      tokenSource: tokens,
      httpClient: MockClient((request) async {
        httpCalls += 1;
        return http.Response('{"error":"internal_error"}', 500);
      }),
    );

    await expectLater(
      client.get('/api/users'),
      throwsA(
        isA<ApiHttpException>()
            .having((e) => e.statusCode, 'statusCode', 500)
            .having((e) => e.message, 'message', 'internal_error')
            .having((e) => e.errorCode, 'errorCode', 'internal_error'),
      ),
    );
    expect(httpCalls, 1);
    expect(tokens.forceRefreshCalls, [false]);
  });

  test('throws when the API base URL is not configured', () async {
    final client = buildClient(
      tokenSource: FakeTokenSource(['token']),
      httpClient: MockClient((request) async => http.Response('', 200)),
      baseUrl: '',
    );

    await expectLater(
      client.get('/health', requireAuth: false),
      throwsA(isA<ApiConfigException>()),
    );
  });

  test('POST/PATCH/DELETE share the same Bearer auth path', () async {
    final methods = <String>[];
    final client = buildClient(
      tokenSource: FakeTokenSource(['firebase-id-token']),
      httpClient: MockClient((request) async {
        methods.add(request.method);
        expect(request.headers['Authorization'], 'Bearer firebase-id-token');
        return http.Response('{}', 200);
      }),
    );

    await client.post('/api/example', body: {'ok': true});
    await client.patch('/api/example', body: {'ok': true});
    await client.delete('/api/example');

    expect(methods, ['POST', 'PATCH', 'DELETE']);
  });

  test('unauthenticated GET /health does not require a Firebase user', () async {
    http.Request? captured;
    final client = buildClient(
      tokenSource: FakeTokenSource([null]),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          '{"status":"ok","database":"connected"}',
          200,
        );
      }),
    );

    final json = await client.getJson('/health', requireAuth: false);

    expect(captured!.headers.containsKey('Authorization'), isFalse);
    expect(json, isA<Map>());
    expect((json as Map)['status'], 'ok');
  });
}
