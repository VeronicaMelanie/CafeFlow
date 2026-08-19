import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/pwa/pwa_responsive.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/location_color_utils.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/employee_bottom_nav_bar.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../locations/presentation/location_providers.dart';
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
    final l10n = L10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: userAsync.when(
        data: (user) {
          if (user == null) return Center(child: Text(l10n.notSignedIn()));

          return Column(
            children: [
              ScreenHeader(
                title: l10n.pick('Statistics', 'Statistici'),
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
        error: (e, st) => Center(child: Text(l10n.errorWith(e))),
      ),
    );
  }

  Widget _buildMonthlyOverview(dynamic user, TextTheme textTheme) {
    final now = DateTime.now();
    final l10n = L10n.of(context);
    final shiftsAsync = ref.watch(shiftRepositoryProvider).getUserShiftsForMonth(user.uid, now);

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10n.of(context).pick('Monthly summary', 'Rezumat lunar'),
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
                          _buildStatItem(l10n.pick('Worked', 'Lucrate'), '${totalHours.toStringAsFixed(1)}h', AppColors.softPink),
                          _buildStatItem(l10n.pick('Target', 'Țintă'), '${targetHours.toInt()}h', AppColors.softYellow),
                          _buildStatItem(l10n.pick('Left', 'Rămase'), '${remaining.toStringAsFixed(0)}h', AppColors.softGreen),
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
                                L10n.of(context).pick('Progress', 'Progres'),
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
            L10n.of(context).pick('By location', 'Pe locații'),
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
              final names = watchLocationNames(ref);
              return Column(
                children: [
                  for (var i = 0; i < names.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    _buildLocationRow(
                      names[i],
                      shifts
                          .where((s) => s.location == names[i])
                          .fold(0.0, (sum, s) => sum + s.durationInHours),
                      LocationColorUtils.backgroundFor(names[i]),
                    ),
                  ],
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
            L10n.of(context).pick('Recent shifts', 'Ture recente'),
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
                return Text(
                  L10n.of(context).pick('No recent shifts', 'Nu există ture recente'),
                  style: const TextStyle(color: AppColors.textLight),
                );
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
    final l10n = L10n.of(context);
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
              color: LocationColorUtils.backgroundFor(shift.location),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Icon(
              Icons.store_outlined,
              size: 16,
              color: LocationColorUtils.foregroundFor(shift.location),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE, MMM dd', l10n.isRo ? null : l10n.locale.languageCode).format(shift.date),
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
