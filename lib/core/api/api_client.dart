import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';
import 'auth_token_source.dart';

/// HTTP client for the CafeFlow PostgreSQL API.
///
/// Attaches `Authorization: Bearer <Firebase ID token>` on authenticated
/// requests. GET/POST/PATCH/PUT/DELETE share one send path so write methods
/// can be added at call sites later without changing auth or error handling.
class ApiClient {
  ApiClient({
    required AuthTokenSource tokenSource,
    http.Client? httpClient,
    String? baseUrl,
    Duration timeout = const Duration(seconds: 20),
  })  : _tokenSource = tokenSource,
        _ownsClient = httpClient == null,
        _http = httpClient ?? http.Client(),
        _baseUrl = ApiConfig.stripTrailingSlash(baseUrl ?? ApiConfig.baseUrl),
        _timeout = timeout;

  final AuthTokenSource _tokenSource;
  final http.Client _http;
  final bool _ownsClient;
  final String _baseUrl;
  final Duration _timeout;

  String get baseUrl => _baseUrl;

  Future<http.Response> get(
    String path, {
    Map<String, String>? query,
    bool requireAuth = true,
  }) {
    return send('GET', path, query: query, requireAuth: requireAuth);
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool requireAuth = true,
  }) {
    return send('POST', path, body: body, query: query, requireAuth: requireAuth);
  }

  Future<http.Response> patch(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool requireAuth = true,
  }) {
    return send(
      'PATCH',
      path,
      body: body,
      query: query,
      requireAuth: requireAuth,
    );
  }

  Future<http.Response> put(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool requireAuth = true,
  }) {
    return send('PUT', path, body: body, query: query, requireAuth: requireAuth);
  }

  Future<http.Response> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool requireAuth = true,
  }) {
    return send(
      'DELETE',
      path,
      body: body,
      query: query,
      requireAuth: requireAuth,
    );
  }

  Future<dynamic> getJson(
    String path, {
    Map<String, String>? query,
    bool requireAuth = true,
  }) async {
    final response = await get(
      path,
      query: query,
      requireAuth: requireAuth,
    );
    return decodeJson(response);
  }

  Future<dynamic> postJson(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool requireAuth = true,
  }) async {
    final response = await post(
      path,
      body: body,
      query: query,
      requireAuth: requireAuth,
    );
    return decodeJson(response);
  }

  Future<dynamic> patchJson(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool requireAuth = true,
  }) async {
    final response = await patch(
      path,
      body: body,
      query: query,
      requireAuth: requireAuth,
    );
    return decodeJson(response);
  }

  Future<dynamic> putJson(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool requireAuth = true,
  }) async {
    final response = await put(
      path,
      body: body,
      query: query,
      requireAuth: requireAuth,
    );
    return decodeJson(response);
  }

  dynamic decodeJson(http.Response response) {
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<http.Response> send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool requireAuth = true,
    bool isRetry = false,
  }) async {
    if (_baseUrl.isEmpty) {
      throw const ApiConfigException();
    }

    String? token;
    if (requireAuth) {
      token = await _tokenSource.getIdToken(forceRefresh: isRetry);
      if (token == null || token.isEmpty) {
        throw const ApiUnauthenticatedException();
      }
    }

    final uri = _uri(path, query);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };

    final response = await _dispatch(method, uri, headers, body);

    if (response.statusCode == 401 && requireAuth && !isRetry) {
      return send(
        method,
        path,
        body: body,
        query: query,
        requireAuth: requireAuth,
        isRetry: true,
      );
    }

    _throwIfHttpError(response);
    return response;
  }

  void close() {
    if (_ownsClient) {
      _http.close();
    }
  }

  Uri _uri(String path, Map<String, String>? query) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$normalized');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  String? _encodeBody(Object? body) {
    if (body == null) return null;
    if (body is String) return body;
    return jsonEncode(body);
  }

  Future<http.Response> _dispatch(
    String method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
  ) async {
    final request = http.Request(method, uri);
    request.headers.addAll(headers);
    final encoded = _encodeBody(body);
    if (encoded != null) {
      request.body = encoded;
    }

    try {
      final streamed = await _http.send(request).timeout(_timeout);
      return http.Response.fromStream(streamed);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Network error: $error');
    }
  }

  void _throwIfHttpError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ApiHttpException(
      statusCode: response.statusCode,
      body: response.body,
      message: _messageFrom(response),
    );
  }

  String _messageFrom(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // Keep the generic HTTP message.
    }
    return 'HTTP ${response.statusCode}';
  }
}
