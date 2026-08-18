import 'package:fivetogo_scheduler/core/api/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    ApiConfig.debugOverride = null;
  });

  test('isHttpsApiUrl accepts HTTPS hosts and rejects HTTP', () {
    expect(ApiConfig.isHttpsApiUrl('https://api.example.com'), isTrue);
    expect(ApiConfig.isHttpsApiUrl('https://api.example.com/v1'), isTrue);
    expect(ApiConfig.isHttpsApiUrl('http://127.0.0.1:3000'), isFalse);
    expect(ApiConfig.isHttpsApiUrl('http://10.0.2.2:3000'), isFalse);
    expect(ApiConfig.isHttpsApiUrl(''), isFalse);
    expect(ApiConfig.isHttpsApiUrl('not-a-url'), isFalse);
  });

  test('debugOverride supplies the URL for local development', () {
    ApiConfig.debugOverride = 'http://127.0.0.1:3000/';
    expect(ApiConfig.baseUrl, 'http://127.0.0.1:3000');
    expect(ApiConfig.isConfigured, isTrue);
  });
}
