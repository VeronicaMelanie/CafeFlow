import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/location_color_utils.dart';
import '../../domain/shift_model.dart';

Future<void> showTeamRosterDaySheet({
  required BuildContext context,
  required DateTime date,
  required List<ShiftModel> shifts,
  required List<String> locationNames,
  String? currentUserId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.pureWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final l10n = L10n.of(context);
      final approved = shifts
          .where((shift) => shift.status == 'approved')
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.huge,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat(
                  'EEEE d MMMM',
                  l10n.isRo ? null : l10n.locale.languageCode,
                ).format(date),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.pick(
                  'Published roster — who is working this day',
                  'Program publicat — cine lucrează în această zi',
                ),
                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final location in locationNames)
                _LocationRoster(
                  location: location,
                  shifts: approved
                      .where((shift) => shift.location == location)
                      .toList(),
                  currentUserId: currentUserId,
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _LocationRoster extends StatelessWidget {
  const _LocationRoster({
    required this.location,
    required this.shifts,
    required this.currentUserId,
  });

  final String location;
  final List<ShiftModel> shifts;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: LocationColorUtils.backgroundFor(location),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: LocationColorUtils.foregroundFor(location),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (shifts.isEmpty)
            Text(
              l10n.pick('Nobody scheduled', 'Nimeni programat'),
              style: const TextStyle(fontSize: 13, color: AppColors.textLight),
            )
          else
            for (final shift in shifts)
              _ShiftRow(
                shift: shift,
                isMe: shift.userId == currentUserId,
              ),
        ],
      ),
    );
  }
}

class _ShiftRow extends StatelessWidget {
  const _ShiftRow({required this.shift, required this.isMe});

  final ShiftModel shift;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final hours =
        '${DateFormat('HH:mm').format(shift.startTime)} – ${DateFormat('HH:mm').format(shift.endTime)}';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.brandMustard.withValues(alpha: 0.22)
            : AppColors.offWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isMe
              ? AppColors.brandMustard.withValues(alpha: 0.55)
              : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isMe
                  ? '${shift.userName} (${l10n.pick('you', 'tu')})'
                  : shift.userName,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.textDark,
              ),
            ),
          ),
          Text(
            hours,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
