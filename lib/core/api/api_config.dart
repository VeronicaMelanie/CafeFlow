import 'package:flutter/foundation.dart';

/// Central API base URL. Never hardcode this in repositories.
///
/// Production (Android, iOS, web release) — HTTPS only:
/// `flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_API_HOST`
/// `flutter build ios --release --dart-define=API_BASE_URL=https://YOUR_API_HOST`
/// `flutter build web --release --dart-define=API_BASE_URL=https://YOUR_API_HOST`
///
/// Local development:
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
      return _productionUrl(stripTrailingSlash(override));
    }
    if (fromEnvironment.trim().isNotEmpty) {
      return _productionUrl(stripTrailingSlash(fromEnvironment.trim()));
    }
    return _productionUrl(stripTrailingSlash(_debugPlatformDefault()));
  }

  static bool get isConfigured => baseUrl.isNotEmpty;

  static String stripTrailingSlash(String url) {
    if (url.length > 1 && url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Release builds must use HTTPS. HTTP localhost is debug-only.
  static bool isHttpsApiUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        !uri.host.contains(' ');
  }

  static String _productionUrl(String url) {
    if (!kReleaseMode || url.isEmpty) return url;
    return isHttpsApiUrl(url) ? url : '';
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
