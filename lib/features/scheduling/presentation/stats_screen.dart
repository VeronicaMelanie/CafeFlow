import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/pwa/pwa_responsive.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/employee_bottom_nav_bar.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/shift_model.dart';
import '../data/vacation_repository.dart';
import '../utils/monthly_progress_calculator.dart';
import 'scheduling_providers.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Not logged in'));

          return Column(
            children: [
              ScreenHeader(
                title: 'Statistics',
                topPadding: PwaResponsive.topSafePadding(context) + AppSpacing.lg,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    EmployeeBottomNavMetrics.contentBottomPadding(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMonthlyOverview(user, textTheme),
                      const SizedBox(height: AppSpacing.xxl),
                      _buildLocationBreakdown(user, textTheme),
                      const SizedBox(height: AppSpacing.xxl),
                      _buildRecentActivity(user, textTheme),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Scaffold(body: AppLoadingIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildMonthlyOverview(dynamic user, TextTheme textTheme) {
    final now = DateTime.now();
    final shiftsAsync = ref.watch(shiftRepositoryProvider).getUserShiftsForMonth(user.uid, now);

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Overview',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.lg),
          StreamBuilder<List<ShiftModel>>(
            stream: shiftsAsync,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Column(
                  children: [
                    AppStatSkeletonRow(),
                    SizedBox(height: AppSpacing.lg),
                    AppSkeleton(height: 10, borderRadius: AppSpacing.radiusSm),
                  ],
                );
              }

              final shifts = snapshot.data!;

              return StreamBuilder(
                stream: ref.read(vacationRepositoryProvider).getVacationsForUser(user.uid),
                builder: (context, vacSnap) {
                  final vacations = vacSnap.data ?? [];
                  final monthProgress = MonthlyProgressCalculator.calculate(
                    shifts: shifts,
                    vacations: vacations,
                    month: now,
                    targetHours: user.monthlyTargetHours.toDouble(),
                  );
                  final totalHours = monthProgress.workedHours;
                  final targetHours = monthProgress.targetHours;
                  final remaining = monthProgress.remainingHours;
                  final progress = monthProgress.progress;

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem('Worked', '${totalHours.toStringAsFixed(1)}h', AppColors.softPink),
                          _buildStatItem('Target', '${targetHours.toInt()}h', AppColors.softYellow),
                          _buildStatItem('Remaining', '${remaining.toStringAsFixed(0)}h', AppColors.softGreen),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progress',
                                style: textTheme.bodySmall?.copyWith(color: AppColors.textLight),
                              ),
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: AppColors.borderLight,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPink),
                              minHeight: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textLight),
        ),
      ],
    );
  }

  Widget _buildLocationBreakdown(dynamic user, TextTheme textTheme) {
    final now = DateTime.now();
    final shiftsAsync = ref.watch(shiftRepositoryProvider).getUserShiftsForMonth(user.uid, now);

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location Breakdown',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.lg),
          StreamBuilder<List<ShiftModel>>(
            stream: shiftsAsync,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const AppLoadingIndicator(size: 24);
              }

              final shifts = snapshot.data!;
              final garaHours = shifts.where((s) => s.location == 'Gara').fold(0.0, (sum, s) => sum + s.durationInHours);
              final avantgardenHours = shifts.where((s) => s.location == 'Avantgarden').fold(0.0, (sum, s) => sum + s.durationInHours);

              return Column(
                children: [
                  _buildLocationRow('Gara', garaHours, AppColors.softGreen),
                  const SizedBox(height: AppSpacing.md),
                  _buildLocationRow('Avantgarden', avantgardenHours, AppColors.softYellow),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(String location, double hours, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            location,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          '${hours.toStringAsFixed(1)}h',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(dynamic user, TextTheme textTheme) {
    return AppSurface(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Shifts',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.lg),
          StreamBuilder<List<ShiftModel>>(
            stream: ref.watch(shiftRepositoryProvider).getUserShiftsForMonth(user.uid, DateTime.now()),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const AppLoadingIndicator(size: 24);
              }

              final shifts = snapshot.data!;
              final recentShifts = shifts.take(5).toList();

              if (recentShifts.isEmpty) {
                return const Text('No recent shifts', style: TextStyle(color: AppColors.textLight));
              }

              return Column(
                children: recentShifts.map((shift) {
                  return _buildShiftItem(shift);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShiftItem(ShiftModel shift) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: shift.location == 'Gara' ? AppColors.softGreen : AppColors.softYellow,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Icon(
              Icons.store_outlined,
              size: 16,
              color: shift.location == 'Gara' ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE, MMM dd').format(shift.date),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${DateFormat('HH:mm').format(shift.startTime)} - ${DateFormat('HH:mm').format(shift.endTime)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          Text(
            '${shift.durationInHours.toStringAsFixed(1)}h',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
