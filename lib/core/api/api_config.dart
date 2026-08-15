import 'package:flutter/foundation.dart';

/// Central API base URL. Never hardcode this in repositories.
///
/// Override for any platform / environment:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000`
///
/// Debug defaults (never used in release):
/// - Web and desktop: `http://127.0.0.1:3000` (same machine as the backend)
/// - Android / iOS: no default — `127.0.0.1` would be the device itself.
///   Emulator example: `--dart-define=API_BASE_URL=http://10.0.2.2:3000`
///   Physical device: host LAN IP, not localhost.
class ApiConfig {
  ApiConfig._();

  static const String fromEnvironment = String.fromEnvironment('API_BASE_URL');

  /// Test-only override. Production code should not set this.
  static String? debugOverride;

  static String get baseUrl {
    final override = debugOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return stripTrailingSlash(override);
    }
    if (fromEnvironment.trim().isNotEmpty) {
      return stripTrailingSlash(fromEnvironment.trim());
    }
    return stripTrailingSlash(_debugPlatformDefault());
  }

  static bool get isConfigured => baseUrl.isNotEmpty;

  static String stripTrailingSlash(String url) {
    if (url.length > 1 && url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }

  static String _debugPlatformDefault() {
    if (kReleaseMode) return '';
    if (kIsWeb) return 'http://127.0.0.1:3000';
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return 'http://127.0.0.1:3000';
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return '';
    }
  }
}
