import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/pwa/pwa_responsive.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/employee_bottom_nav_bar.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_providers.dart';

class TeamScreen extends ConsumerWidget {
  const TeamScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Column(
        children: [
          ScreenHeader(
            title: 'Team Members',
            topPadding: PwaResponsive.topSafePadding(context) + AppSpacing.lg,
          ),
          Expanded(
            child: ref.watch(allEmployeesProvider).when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.xl),
                itemCount: 5,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.lg),
                  child: AppSkeleton(height: 80, borderRadius: AppSpacing.radiusLg),
                ),
              ),
              error: (error, _) => const EmptyState(
                icon: Icons.people_outline,
                title: 'No team members found',
              ),
              data: (employees) {
                if (employees.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_outline,
                    title: 'No team members found',
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    EmployeeBottomNavMetrics.contentBottomPadding(context),
                  ),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final employee = employees[index];
                    return _buildEmployeeCard(employee);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(UserModel employee) {
    final colors = [AppColors.softPink, AppColors.softYellow, AppColors.softGreen, AppColors.softPurple, AppColors.softBlue];
    final color = colors[employee.uid.length % colors.length];

    return AppSurface(
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.85),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            child: Center(
              child: Text(
                employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  employee.workType,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(Icons.store_outlined, size: 14, color: AppColors.primaryPink),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      employee.primaryLocation,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.softGreen.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Text(
              '${employee.monthlyTargetHours}h',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
