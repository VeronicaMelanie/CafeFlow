import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Layered elevation shadows for depth without heavy contrast.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> get xs => [
        BoxShadow(
          color: AppColors.shadowColor.withValues(alpha: 0.06),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get sm => [
        BoxShadow(
          color: AppColors.shadowColor.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
          color: AppColors.shadowColor.withValues(alpha: 0.1),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: AppColors.shadowColor.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
          color: AppColors.shadowColor.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: AppColors.shadowColor.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get xl => [
        BoxShadow(
          color: AppColors.shadowColor.withValues(alpha: 0.14),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: AppColors.shadowColor.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.25),
          blurRadius: 20,
          spreadRadius: -2,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> coloredGlow(Color color, {double intensity = 0.3}) => [
        BoxShadow(
          color: color.withValues(alpha: intensity),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}
