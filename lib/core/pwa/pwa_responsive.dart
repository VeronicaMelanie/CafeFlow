import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'pwa_detector.dart';

/// Layout helpers for iPhone PWA standalone mode and mobile web.
class PwaResponsive {
  static bool get isWebPwaContext => kIsWeb;

  static double bottomSafePadding(BuildContext context) {
    final padding = MediaQuery.paddingOf(context).bottom;
    if (!kIsWeb) return padding;
    if (pwaIsStandalone() || padding > 0) {
      return padding + 8;
    }
    return 16;
  }

  static double topSafePadding(BuildContext context) {
    return MediaQuery.paddingOf(context).top;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final mq = MediaQuery.of(context);
    return EdgeInsets.fromLTRB(
      20 + mq.padding.left,
      8,
      20 + mq.padding.right,
      bottomSafePadding(context),
    );
  }

  static bool isCompactWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static double maxContentWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w > 900) return 720;
    return w;
  }
}
