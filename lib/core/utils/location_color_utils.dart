import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Consistent accent colors for any location id (supports unlimited locations).
class LocationColorUtils {
  LocationColorUtils._();

  static const _backgrounds = [
    AppColors.softGreen,
    AppColors.softYellow,
    AppColors.softPink,
    Color(0xFFE3F2FD),
    Color(0xFFF3E5F5),
    Color(0xFFE8F5E9),
  ];

  static const _foregrounds = [
    Colors.green,
    Colors.orange,
    Colors.pink,
    Colors.blue,
    Colors.purple,
    Colors.teal,
  ];

  static int _indexFor(String locationId) =>
      locationId.hashCode.abs() % _backgrounds.length;

  static Color backgroundFor(String locationId) =>
      _backgrounds[_indexFor(locationId)];

  static Color foregroundFor(String locationId) =>
      _foregrounds[_indexFor(locationId)];
}
