import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_spacing.dart';

/// Standard gradient screen header with optional back button and actions.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions,
    this.topPadding = 56,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: topPadding,
        bottom: AppSpacing.xl,
        left: AppSpacing.sm,
        right: AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppSpacing.xxxl),
        ),
      ),
      child: Row(
        children: [
          if (onBack != null)
            _GlassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onPressed: onBack!,
            )
          else
            const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: AppColors.glassWhite,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard elevated surface card decoration.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin ?? const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: padding ?? const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: color ?? AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.6),
          width: 0.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}
