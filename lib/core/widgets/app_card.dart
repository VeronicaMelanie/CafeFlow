import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import 'interactive_scale.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool enableHover;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
    this.backgroundColor,
    this.enableHover = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppSpacing.radiusXl;

    final card = AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.easeOut,
      margin: margin ?? const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: padding ?? const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.pureWhite,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.6),
          width: 0.5,
        ),
        boxShadow: AppShadows.md,
      ),
      child: child,
    );

    if (onTap == null) return card;

    return InteractiveScale(
      enabled: enableHover,
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: card,
    );
  }
}
