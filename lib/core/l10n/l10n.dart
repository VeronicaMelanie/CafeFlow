import 'package:flutter/material.dart';

class L10n {
  const L10n(this.locale);

  final Locale locale;

  bool get isRo => locale.languageCode == 'ro';

  String pick(String en, String ro) => isRo ? ro : en;

  String weekdayShort(int weekday) {
    final i = weekday.clamp(1, 7) - 1;
    return pick(
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
      const ['Lu', 'Ma', 'Mi', 'Jo', 'Vi', 'Sâ', 'Du'][i],
    );
  }

  String workTypeLabel(String type) {
    final t = type.toLowerCase();
    if (t.contains('part')) {
      return pick('Part-time', 'Normă parțială');
    }
    return pick('Full-time', 'Normă întreagă');
  }

  String roleLabel(String role) {
    if (role.toLowerCase() == 'admin') return 'Admin';
    return pick('Employee', 'Angajat');
  }

  String notSignedIn() => pick('You are not signed in', 'Nu ești autentificat');

  String errorWith(Object e) => '${pick('Error', 'Eroare')}: $e';

  static const fallback = L10n(Locale('ro'));

  static L10n of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<L10nScope>()?.l10n ??
        fallback;
  }
}

class L10nScope extends InheritedWidget {
  const L10nScope({super.key, required this.l10n, required super.child});

  final L10n l10n;

  @override
  bool updateShouldNotify(L10nScope oldWidget) => l10n.locale != oldWidget.l10n.locale;
}
