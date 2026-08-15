import 'dart:convert';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => 'ApiException: $message';
}

class ApiConfigException extends ApiException {
  const ApiConfigException([
    super.message = 'API_BASE_URL is not configured',
  ]);
}

class ApiUnauthenticatedException extends ApiException {
  const ApiUnauthenticatedException([
    super.message = 'Not signed in',
  ]);
}

class ApiHttpException extends ApiException {
  const ApiHttpException({
    required this.statusCode,
    required this.body,
    String? message,
  }) : super(message ?? 'HTTP $statusCode');

  final int statusCode;
  final String body;

  String? get errorCode {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // Body is not JSON; callers can still read [body].
    }
    return null;
  }

  @override
  String toString() => 'ApiHttpException: $statusCode $message';
}
