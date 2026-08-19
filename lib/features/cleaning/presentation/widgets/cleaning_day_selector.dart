import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/cleaning_list_key.dart';

class CleaningDaySelector extends StatelessWidget {
  final CleaningListKey selectedKey;
  final ValueChanged<CleaningListKey> onChanged;

  const CleaningDaySelector({
    super.key,
    required this.selectedKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final key in CleaningListKey.ordered) ...[
            _CleaningDayChip(
              label: key.shortLabelFor(L10n.of(context)),
              isSelected: selectedKey == key,
              onTap: () => onChanged(key),
            ),
            if (key != CleaningListKey.sunday) const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _CleaningDayChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CleaningDayChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.brandTurquoise.withValues(alpha: 0.18)
                : AppColors.pureWhite,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            border: Border.all(
              color: isSelected
                  ? AppColors.brandTurquoise.withValues(alpha: 0.45)
                  : AppColors.borderLight.withValues(alpha: 0.8),
            ),
            boxShadow: isSelected ? AppShadows.sm : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: isSelected ? AppColors.brandTurquoise : AppColors.textLight,
            ),
          ),
        ),
      ),
    );
  }
}
