import 'package:fivetogo_scheduler/core/api/api_client.dart';
import 'package:fivetogo_scheduler/core/api/auth_token_source.dart';
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

ApiClient buildTestApiClient({
  required MockClient httpClient,
  AuthTokenSource? tokenSource,
  String baseUrl = 'http://127.0.0.1:3000',
}) {
  return ApiClient(
    tokenSource: tokenSource ?? FakeTokenSource(['firebase-id-token']),
    httpClient: httpClient,
    baseUrl: baseUrl,
  );
}

MockClient jsonMock(int statusCode, String body) {
  return MockClient((request) async => http.Response(body, statusCode));
}
