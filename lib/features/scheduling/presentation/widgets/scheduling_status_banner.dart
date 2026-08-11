import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/scheduling_config_repository.dart';

class SchedulingStatusBanner extends StatelessWidget {
  final MonthSchedulingAccess access;

  const SchedulingStatusBanner({super.key, required this.access});

  @override
  Widget build(BuildContext context) {
    final message = access.bannerMessage;
    if (message == null) return const SizedBox.shrink();

    final isLocked = access.calendarMonthLocked || access.adminLockedMonth;
    final icon = isLocked ? Icons.lock_outline : Icons.hourglass_empty;
    final bg = isLocked
        ? AppColors.textLight.withValues(alpha: 0.15)
        : AppColors.softYellow.withValues(alpha: 0.8);
    final fg = isLocked ? AppColors.textDark.withValues(alpha: 0.7) : AppColors.textDark;

    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.easeOut,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isLocked
              ? AppColors.textLight.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
