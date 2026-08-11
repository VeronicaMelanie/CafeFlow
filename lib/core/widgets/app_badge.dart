import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_spacing.dart';

class AppBadge extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;

  const AppBadge({
    super.key,
    required this.label,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.softPink,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: (textColor ?? AppColors.primaryPink).withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor ?? AppColors.primaryPink,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
