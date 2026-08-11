/// Production PWA URL — update after first Firebase Hosting deploy if different.
class PwaConfig {
  PwaConfig._();

  static const String hostingUrl = 'https://cafeflow-5tg.web.app';

  /// QR / install links append this query so the install tutorial opens automatically.
  static const String installQueryParam = 'install';

  static String get installLandingUrl => '$hostingUrl/?$installQueryParam=1';

  static const String installTutorialDismissedKey =
      'pwa_install_tutorial_dismissed';

  static const String sessionInstallFlagKey = 'cafeflow_show_install';
}
