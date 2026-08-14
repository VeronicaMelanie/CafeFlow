import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/admin_guard.dart';
import '../../../core/widgets/interactive_scale.dart';
import 'manage_schedule_screen.dart';
import 'vacation_approval_screen.dart';
import 'employee_management_screen.dart';
import 'consumption_log_screen.dart';
import 'distribution_screen.dart';
import 'calendar_schedule_screen.dart';
import '../../cleaning/presentation/cleaning_lists_admin_screen.dart';
import 'open_scheduling_screen.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            _buildHeader(context, ref),
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.all(AppSpacing.xl),
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.lg,
                mainAxisSpacing: AppSpacing.lg,
                children: [
                  _buildAdminCard(
                    context,
                    'Current\nSchedule',
                    Icons.calendar_today_outlined,
                    AppColors.softBlue,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CalendarScheduleScreen(),
                        ),
                      );
                    },
                  ),
                  _buildAdminCard(
                    context,
                    'Open\nScheduling',
                    Icons.event_available_outlined,
                    AppColors.softPink,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OpenSchedulingScreen(),
                        ),
                      );
                    },
                  ),
                  _buildAdminCard(
                    context,
                    'Manage\nSchedule',
                    Icons.calendar_month_outlined,
                    AppColors.softPurple,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageScheduleScreen(),
                        ),
                      );
                    },
                  ),
                  _buildAdminCard(
                    context,
                    'Approve\nVacations',
                    Icons.beach_access_outlined,
                    AppColors.softYellow,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VacationApprovalScreen(),
                        ),
                      );
                    },
                  ),
                  _buildAdminCard(
                    context,
                    'View\nEmployees',
                    Icons.people_outline,
                    AppColors.softGreen,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const EmployeeManagementScreen(),
                        ),
                      );
                    },
                  ),
                  _buildAdminCard(
                    context,
                    'Consumption\nLogs',
                    Icons.coffee_outlined,
                    AppColors.softPurple,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ConsumptionLogScreen(),
                        ),
                      );
                    },
                  ),
                  _buildAdminCard(
                    context,
                    'Cleaning\nTo-Do Lists',
                    Icons.cleaning_services_outlined,
                    AppColors.brandGreen,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const CleaningListsAdminScreen(),
                        ),
                      );
                    },
                  ),
                  _buildAdminCard(
                    context,
                    'Distribute\nApp',
                    Icons.qr_code_2_outlined,
                    AppColors.softBlue,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DistributionScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.only(
        top: 56,
        bottom: AppSpacing.xxxl,
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppSpacing.xxxl),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Admin Panel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Managing CafeFlow System',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Material(
                color: AppColors.glassWhite,
                child: IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InteractiveScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(
            color: AppColors.borderLight.withValues(alpha: 0.6),
            width: 0.5,
          ),
          boxShadow: AppShadows.md,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppMotion.normal,
              curve: AppMotion.easeOut,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                boxShadow: AppShadows.xs,
              ),
              child: Icon(
                icon,
                size: 30,
                color: AppColors.textDark.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
