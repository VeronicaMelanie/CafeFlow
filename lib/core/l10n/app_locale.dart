import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'app_locale';

class AppLocaleController extends StateNotifier<Locale> {
  AppLocaleController(super.state);

  static Future<Locale> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code == 'en') return const Locale('en');
    return const Locale('ro');
  }

  Future<void> setCode(String code) async {
    final locale = code == 'en' ? const Locale('en') : const Locale('ro');
    Intl.defaultLocale = locale.languageCode;
    await initializeDateFormatting(locale.languageCode);
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
  }
}

final appLocaleProvider =
    StateNotifierProvider<AppLocaleController, Locale>((ref) {
  return AppLocaleController(const Locale('ro'));
});
