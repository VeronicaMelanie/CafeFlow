import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/interactive_scale.dart';
import '../domain/user_model.dart';
import 'auth_providers.dart';

/// Full-screen gate shown until the employee selects a contract type.
/// Using a dedicated screen avoids modal barriers dimming routes pushed on top.
class ContractTypeOnboardingScreen extends ConsumerWidget {
  const ContractTypeOnboardingScreen({
    super.key,
    required this.user,
  });

  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final displayName =
        user.name.isNotEmpty ? user.name : l10n.roleLabel('employee');

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                l10n.pick('Welcome, $displayName', 'Bine ai venit, $displayName'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.pick('What type of contract do you have?', 'Ce tip de contract ai?'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              ContractTypeOptionTile(
                title: l10n.workTypeLabel('full_time'),
                subtitle: l10n.pick(
                  'Standard monthly target (160h)',
                  'Țintă lunară standard (160h)',
                ),
                accent: AppColors.brandGreen,
                icon: Icons.calendar_today_rounded,
                onTap: () => _save(context, ref, 'full_time'),
              ),
              const SizedBox(height: AppSpacing.md),
              ContractTypeOptionTile(
                title: l10n.workTypeLabel('part_time'),
                subtitle: l10n.pick(
                  'Reduced monthly target (80h)',
                  'Țintă lunară redusă (80h)',
                ),
                accent: AppColors.brandMustard,
                icon: Icons.schedule_rounded,
                onTap: () => _save(context, ref, 'part_time'),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    String contractType,
  ) async {
    await ref.read(authRepositoryProvider).setContractType(
          uid: user.uid,
          contractType: contractType,
        );
    ref.invalidate(currentUserProvider);
  }
}

class ContractTypeOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  const ContractTypeOptionTile({
    super.key,
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
