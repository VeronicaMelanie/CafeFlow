import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pwa_config.dart';
import 'pwa_detector.dart';

/// Decides when to show the iOS "Add to Home Screen" tutorial on web.
class PwaInstallService {
  Future<bool> shouldShowInstallTutorial() async {
    if (!kIsWeb) return false;
    if (pwaIsStandalone()) return false;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(PwaConfig.installTutorialDismissedKey) == true) {
      return false;
    }

    if (pwaShouldShowInstallFromUrl()) return true;

    // iPhone/iPad Safari — primary install audience
    if (pwaIsIosDevice()) return true;

    return false;
  }

  Future<void> dismissInstallTutorial({bool permanent = true}) async {
    if (!permanent) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PwaConfig.installTutorialDismissedKey, true);
  }

  Future<void> resetInstallTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PwaConfig.installTutorialDismissedKey);
  }
}
