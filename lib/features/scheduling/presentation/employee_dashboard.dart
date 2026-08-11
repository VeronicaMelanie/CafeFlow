import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/presentation/auth_providers.dart';
import 'scheduling_providers.dart';
import '../../consumption/presentation/consumption_entry_screen.dart';
import 'submit_availability_screen.dart';
import 'vacation_status_screen.dart';
import 'my_full_schedule_screen.dart';
import '../domain/shift_model.dart';
import '../data/vacation_repository.dart';
import '../utils/monthly_progress_calculator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/pwa/pwa_responsive.dart';
import '../../../core/pwa/widgets/pwa_limitations_banner.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/interactive_scale.dart';
import '../../../core/widgets/employee_bottom_nav_bar.dart';

class EmployeeDashboard extends ConsumerStatefulWidget {
  const EmployeeDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends ConsumerState<EmployeeDashboard> {
  @override
  void initState() {
    super.initState();
    _scheduleReminders();
  }

  Future<void> _scheduleReminders() async {
    await Future.delayed(const Duration(seconds: 2));
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      final shifts = await ref
          .read(shiftRepositoryProvider)
          .getEmployeeShifts(user.uid);
      final notificationService = NotificationService();
      await notificationService.cancelAllNotifications();
      for (int i = 0; i < shifts.length; i++) {
        final shift = shifts[i];
        if (shift.status == 'approved') {
          final reminderTime = shift.startTime.subtract(
            const Duration(days: 1),
          );
          if (reminderTime.isAfter(DateTime.now())) {
            await notificationService.scheduleShiftReminder(
              id: i,
              title: 'Shift Tomorrow!',
              body: 'Reminder: You have a shift tomorrow at  from  to .',
              scheduledDate: reminderTime,
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final location = ref.watch(selectedLocationProvider);

    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Not logged in'));

          return Column(
            children: [
              _buildHeader(context, user.name),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    EmployeeBottomNavMetrics.contentBottomPadding(context),
                  ),
                  child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.md),
                          const PwaLimitationsBanner(),
                          const SizedBox(height: AppSpacing.md),
                          _buildLocationSwitcher(location),
                          const SizedBox(height: AppSpacing.xxl),
                          _buildMonthlyStatsCards(
                            user.uid,
                            user.monthlyTargetHours,
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          _buildUpcomingShiftsSection(user.uid),
                          const SizedBox(height: AppSpacing.xxxl),
                          _buildActionCards(context),
                          const SizedBox(height: AppSpacing.lg),
                          _buildVacationCard(context),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const AppLoadingIndicator(),
        error: (e, st) => Center(child: Text('Error: ')),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String userName) {
    final top = PwaResponsive.topSafePadding(context);
    final now = DateTime.now();
    return Container(
      padding: EdgeInsets.only(
        top: top + AppSpacing.lg,
        bottom: AppSpacing.xl,
        left: AppSpacing.xl,
        right: AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppSpacing.xxxl),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hi, $userName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEEE, MMM d').format(now),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _HeaderIconButton(
                icon: Icons.notifications_outlined,
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(
                icon: Icons.logout_rounded,
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStatsCards(String userId, int targetHours) {
    final now = DateTime.now();
    return StreamBuilder<List<ShiftModel>>(
      stream: ref
          .read(shiftRepositoryProvider)
          .getUserShiftsForMonth(userId, now),
      builder: (context, shiftSnap) {
        if (shiftSnap.connectionState == ConnectionState.waiting) {
          return const AppStatSkeletonRow();
        }
        return StreamBuilder(
          stream: ref
              .read(vacationRepositoryProvider)
              .getVacationsForUser(userId),
          builder: (context, vacSnap) {
            final shifts = shiftSnap.data ?? [];
            final vacations = vacSnap.data ?? [];
            final progressResult = MonthlyProgressCalculator.calculate(
              shifts: shifts,
              vacations: vacations,
              month: now,
              targetHours: targetHours.toDouble(),
            );
            final completed = progressResult.workedHours;
            final remaining = progressResult.remainingHours;
            final progress = progressResult.progress;

            return Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.pureWhite,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(
                  color: AppColors.borderLight.withValues(alpha: 0.8),
                  width: 0.5,
                ),
                boxShadow: AppShadows.md,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Monthly Progress',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        '${completed.toStringAsFixed(1)} / $targetHours h',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandMustard,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: AppColors.borderLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.brandGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat(
                        'Target',
                        '$targetHours h',
                        AppColors.brandTurquoise,
                      ),
                      _buildMiniStat(
                        'Done',
                        '${completed.toStringAsFixed(1)} h',
                        AppColors.brandGreen,
                      ),
                      _buildMiniStat(
                        'Left',
                        '${remaining.toStringAsFixed(1)} h',
                        AppColors.brandMustard,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMiniStat(String label, String value, Color dotColor) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textLight,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationSwitcher(String location) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.6),
          width: 0.5,
        ),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          _buildLocationItem('Gara', location == 'Gara'),
          _buildLocationItem('Avantgarden', location == 'Avantgarden'),
        ],
      ),
    );
  }

  Widget _buildLocationItem(String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(selectedLocationProvider.notifier).state = label,
        child: AnimatedContainer(
          duration: AppMotion.slow,
          curve: AppMotion.easeOut,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.pureWhite : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill - 3),
            border: isSelected
                ? Border.all(
                    color: AppColors.brandGreen.withValues(alpha: 0.3),
                    width: 0.5,
                  )
                : null,
            boxShadow: isSelected ? AppShadows.xs : null,
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 16,
                  color: isSelected
                      ? AppColors.brandGreen
                      : AppColors.textLight,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      fontSize: 13,
                      color: isSelected
                          ? AppColors.brandGreen
                          : AppColors.textLight,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: AppColors.brandGreen,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingShiftsSection(String userId) {
    final now = DateTime.now();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Shifts',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyFullScheduleScreen(),
                  ),
                );
              },
              icon: const Text(
                'View calendar',
                style: TextStyle(
                  color: AppColors.brandGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              label: const Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: AppColors.brandGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 140,
          child: StreamBuilder<List<ShiftModel>>(
            stream: ref
                .read(shiftRepositoryProvider)
                .getUserShiftsForMonth(userId, now),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: const AppSkeleton(
                      width: 110,
                      height: 140,
                      borderRadius: AppSpacing.radiusLg,
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: '));
              }

              final shifts = snapshot.data ?? [];

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                itemBuilder: (context, index) {
                  final date = now.add(Duration(days: index));
                  final dayShifts = shifts
                      .where(
                        (s) =>
                            s.date.day == date.day &&
                            s.date.month == date.month,
                      )
                      .toList();

                  return _buildShiftCard(
                    date,
                    dayShifts.isNotEmpty ? dayShifts.first : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShiftCard(DateTime date, ShiftModel? shift) {
    final isToday = date.day == DateTime.now().day;
    final colors = [
      AppColors.brandTurquoise.withValues(alpha: 0.15),
      AppColors.brandMustard.withValues(alpha: 0.15),
      AppColors.brandGreen.withValues(alpha: 0.15),
      AppColors.brandPurple.withValues(alpha: 0.15),
    ];
    final color = shift != null
        ? colors[date.day % colors.length]
        : AppColors.pureWhite;

    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: AppSpacing.md),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isToday
              ? AppColors.brandGreen
              : AppColors.borderLight.withValues(alpha: 0.8),
          width: isToday ? 2.0 : 0.5,
        ),
        boxShadow: isToday
            ? AppShadows.coloredGlow(AppColors.brandGreen, intensity: 0.2)
            : AppShadows.xs,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat('EEE').format(date).toUpperCase(),
            style: TextStyle(
              color: isToday
                  ? AppColors.brandGreen
                  : AppColors.textDark.withValues(alpha: 0.7),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          Text(
            '${date.day}',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (shift != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.pureWhite,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${DateFormat('HH:mm').format(shift.startTime)} - ${DateFormat('HH:mm').format(shift.endTime)}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              shift.location,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ] else ...[
            const Text('—', style: TextStyle(color: AppColors.textLight)),
            const Text(
              'No shift',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textLight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCards(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildSmallActionCard(
            'Consumption',
            'Log daily items',
            Icons.emoji_food_beverage_rounded,
            AppColors.brandRed,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConsumptionEntryScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _buildSmallActionCard(
            'Availability',
            'Manage days',
            Icons.calendar_month_rounded,
            AppColors.brandTurquoise,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubmitAvailabilityScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVacationCard(BuildContext context) {
    return InteractiveScale(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const VacationStatusScreen()),
        );
      },
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.brandPurple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(
            color: AppColors.brandPurple.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.pureWhite,
                shape: BoxShape.circle,
                boxShadow: AppShadows.xs,
              ),
              child: const Icon(
                Icons.beach_access_rounded,
                color: AppColors.brandPurple,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vacation Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'View your time off requests',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.brandPurple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color brandColor,
    VoidCallback onTap,
  ) {
    return InteractiveScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: brandColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(
            color: brandColor.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.pureWhite,
                shape: BoxShape.circle,
                boxShadow: AppShadows.xs,
              ),
              child: Icon(icon, color: brandColor),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLight,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: brandColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: AppColors.glassWhite,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
