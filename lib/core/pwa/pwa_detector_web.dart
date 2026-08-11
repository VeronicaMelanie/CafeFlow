// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

bool pwaIsStandalone() {
  return html.window.matchMedia('(display-mode: standalone)').matches ||
      html.window.matchMedia('(display-mode: fullscreen)').matches;
}

bool pwaIsIosDevice() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('iphone') ||
      ua.contains('ipad') ||
      ua.contains('ipod');
}

bool pwaShouldShowInstallFromUrl() {
  final search = html.window.location.search ?? '';
  return search.contains('install=1') || search.contains('install=true');
}

void pwaHideNativeSplash() {
  final splash = html.document.getElementById('cafeflow-splash');
  splash?.classes.add('cafeflow-splash--hidden');
}

bool pwaIsOnline() => html.window.navigator.onLine ?? true;
