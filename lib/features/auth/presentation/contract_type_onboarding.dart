import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/interactive_scale.dart';

Future<String?> showContractTypeOnboarding({
  required BuildContext context,
  required String userName,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ContractTypeSheet(userName: userName),
  );
}

class _ContractTypeSheet extends StatelessWidget {
  final String userName;
  const _ContractTypeSheet({required this.userName});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(
            color: AppColors.borderLight.withValues(alpha: 0.6),
            width: 0.5,
          ),
          boxShadow: AppShadows.xl,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Welcome, $userName',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'What type of contract do you have?',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                _OptionTile(
                  title: 'Full-Time',
                  subtitle: 'Standard monthly target (160h)',
                  accent: AppColors.brandGreen,
                  icon: Icons.calendar_today_rounded,
                  onTap: () => Navigator.pop(context, 'full_time'),
                ),
                const SizedBox(height: AppSpacing.md),
                _OptionTile(
                  title: 'Part-Time',
                  subtitle: 'Reduced monthly target (80h)',
                  accent: AppColors.brandMustard,
                  icon: Icons.schedule_rounded,
                  onTap: () => Navigator.pop(context, 'part_time'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: accent.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.pureWhite,
                shape: BoxShape.circle,
                boxShadow: AppShadows.xs,
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: accent,
            ),
          ],
        ),
      ),
    );
  }
}
