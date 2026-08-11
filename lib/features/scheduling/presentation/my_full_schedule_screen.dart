import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/presentation/auth_providers.dart';
import 'scheduling_providers.dart';
import '../domain/shift_model.dart';

class MyFullScheduleScreen extends ConsumerWidget {
  const MyFullScheduleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) return const Scaffold(body: Center(child: Text('Not logged in')));

    final now = DateTime.now();
    final shiftsAsync = ref.watch(userShiftsProvider(user.uid));

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Column(
        children: [
          ScreenHeader(
            title: 'My Schedule',
            subtitle: DateFormat('MMMM yyyy').format(now),
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: shiftsAsync.when(
              data: (shifts) {
                if (shifts.isEmpty) {
                  return Center(
                    child: Text(
                      'No shifts scheduled for this month.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textLight,
                          ),
                    ),
                  );
                }

                shifts.sort((a, b) => a.date.compareTo(b.date));

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  itemCount: shifts.length,
                  itemBuilder: (context, index) {
                    final shift = shifts[index];
                    return _buildShiftItem(shift);
                  },
                );
              },
              loading: () => const AppLoadingIndicator(),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftItem(ShiftModel shift) {
    final isToday = shift.date.day == DateTime.now().day &&
        shift.date.month == DateTime.now().month &&
        shift.date.year == DateTime.now().year;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isToday ? AppColors.primaryPink : AppColors.borderLight.withValues(alpha: 0.6),
          width: isToday ? 1.5 : 0.5,
        ),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
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
                  DateFormat('EEE').format(shift.date),
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
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textLight),
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: const Text(
                'Approved',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
