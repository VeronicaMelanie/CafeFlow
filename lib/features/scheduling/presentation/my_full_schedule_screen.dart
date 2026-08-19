import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/presentation/auth_providers.dart';
import 'scheduling_providers.dart';
import '../domain/shift_model.dart';
import 'widgets/cover_shift_button.dart';

class MyFullScheduleScreen extends ConsumerWidget {
  const MyFullScheduleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final user = ref.watch(currentUserProvider).value;
    if (user == null)
      return Scaffold(body: Center(child: Text(l10n.notSignedIn())));

    final now = DateTime.now();
    final month = DateTime(now.year, now.month, 1);
    final shiftsAsync = ref.watch(userShiftsProvider(user.uid));
    final availabilityAsync = ref.watch(userAvailabilityForMonthProvider(month));

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Column(
        children: [
          ScreenHeader(
            title: l10n.pick('My schedule', 'Programul meu'),
            subtitle: DateFormat('MMMM yyyy', l10n.isRo ? null : l10n.locale.languageCode).format(now),
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: shiftsAsync.when(
              data: (shifts) {
                final availability = availabilityAsync.valueOrNull ?? const [];
                shifts.sort((a, b) => a.date.compareTo(b.date));
                final assignedDays = {
                  for (final shift in shifts)
                    DateTime(shift.date.year, shift.date.month, shift.date.day),
                };
                final unplaced = availability.where((entry) {
                  final day = DateTime(
                    entry.date.year,
                    entry.date.month,
                    entry.date.day,
                  );
                  return !assignedDays.contains(day);
                }).toList()
                  ..sort((a, b) => a.date.compareTo(b.date));

                if (shifts.isEmpty && unplaced.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.pick(
                        'You have no shifts scheduled this month.',
                        'Nu ai ture programate luna aceasta.',
                      ),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textLight,
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    for (final shift in shifts) _buildShiftItem(context, shift),
                    if (unplaced.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.pick(
                          'Days you marked, not assigned',
                          'Zile bifate, fără tură',
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.pick(
                          'The cafe was already full those days. Check Who\'s working for the published roster.',
                          'Cafeneaua era deja completă în zilele astea. Vezi Cine lucrează pentru programul publicat.',
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final entry in unplaced)
                            Chip(
                              label: Text(
                                DateFormat(
                                  'EEE d MMM',
                                  l10n.isRo ? null : l10n.locale.languageCode,
                                ).format(entry.date),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                );
              },
              loading: () => const AppLoadingIndicator(),
              error: (e, st) => Center(child: Text(l10n.errorWith(e))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftItem(BuildContext context, ShiftModel shift) {
    final l10n = L10n.of(context);
    final isToday =
        shift.date.day == DateTime.now().day &&
        shift.date.month == DateTime.now().month &&
        shift.date.year == DateTime.now().year;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isToday
              ? AppColors.primaryPink
              : AppColors.borderLight.withValues(alpha: 0.6),
          width: isToday ? 1.5 : 0.5,
        ),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.softPink,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.weekdayShort(shift.date.weekday),
                      style: const TextStyle(
                        color: AppColors.primaryPink,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${shift.date.day}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${DateFormat('HH:mm').format(shift.startTime)} - ${DateFormat('HH:mm').format(shift.endTime)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          shift.location,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (shift.status == 'approved')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Text(
                    l10n.pick('Approved', 'Aprobat'),
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          CoverShiftButton(shift: shift),
        ],
      ),
    );
  }
}
