import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import 'interactive_scale.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final double? height;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.backgroundColor,
    this.textColor,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;
    final bgColor = backgroundColor ?? AppColors.primaryPink;

    return InteractiveScale(
      enabled: isEnabled,
      onTap: isEnabled ? onPressed : null,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.easeOut,
        width: isFullWidth ? double.infinity : null,
        height: height ?? 56,
        decoration: BoxDecoration(
          gradient: isEnabled
              ? LinearGradient(
                  colors: [
                    bgColor,
                    bgColor.withValues(alpha: 0.88),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: isEnabled ? null : AppColors.textLight.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          boxShadow: isEnabled ? AppShadows.coloredGlow(bgColor) : null,
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: textColor ?? Colors.white,
                    strokeWidth: 2.5,
                    strokeCap: StrokeCap.round,
                  ),
                )
              : Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor ?? Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}
