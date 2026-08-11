import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_spacing.dart';

/// Shimmer loading placeholder for smooth content transitions.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppSpacing.radiusMd,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _controller.value, 0),
              end: Alignment(1 + 2 * _controller.value, 0),
              colors: [
                AppColors.borderLight,
                AppColors.pureWhite,
                AppColors.borderLight,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Centered loading indicator with brand styling.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.primaryPink,
          strokeCap: StrokeCap.round,
        ),
      ),
    );
  }
}

/// Skeleton card row for stat cards.
class AppStatSkeletonRow extends StatelessWidget {
  const AppStatSkeletonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : AppSpacing.sm),
            child: const AppSkeleton(height: 72, borderRadius: AppSpacing.radiusLg),
          ),
        ),
      ),
    );
  }
}
