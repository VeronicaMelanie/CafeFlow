import 'package:flutter/animation.dart';

/// Motion tokens for consistent micro-interactions.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 300);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve spring = Curves.easeOutBack;

  static const double hoverScale = 1.03;
  static const double pressScale = 0.97;
}
