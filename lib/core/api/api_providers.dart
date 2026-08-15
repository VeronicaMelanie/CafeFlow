import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'auth_token_source.dart';

final authTokenSourceProvider = Provider<AuthTokenSource>((ref) {
  return FirebaseAuthTokenSource();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(tokenSource: ref.watch(authTokenSourceProvider));
  ref.onDispose(client.close);
  return client;
});
