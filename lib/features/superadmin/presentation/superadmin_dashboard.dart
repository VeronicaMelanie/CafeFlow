import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/language_switch.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/interactive_scale.dart';
import '../../../core/widgets/superadmin_guard.dart';
import '../../admin/presentation/admin_dashboard.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../scheduling/presentation/employee_main_shell.dart';
import '../data/superadmin_providers.dart';
import '../data/superadmin_repository.dart';
import 'superadmin_locations_screen.dart';
import 'superadmin_products_screen.dart';
import 'superadmin_records_screen.dart';
import 'superadmin_users_screen.dart';

class SuperadminDashboard extends ConsumerWidget {
  const SuperadminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final overview = ref.watch(superadminOverviewProvider);

    return SuperadminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            _buildHeader(context, ref, l10n),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  overview.when(
                    data: (data) => _OverviewStrip(data: data, l10n: l10n),
                    loading: () => const SizedBox(height: 72),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.lg,
                    mainAxisSpacing: AppSpacing.lg,
                    children: [
                      _card(
                        context,
                        l10n.pick('Users', 'Utilizatori'),
                        Icons.people_outline,
                        AppColors.softPink,
                        () => _open(context, const SuperadminUsersScreen()),
                      ),
                      _card(
                        context,
                        l10n.pick('Products', 'Produse'),
                        Icons.local_cafe_outlined,
                        AppColors.brandMustard,
                        () => _open(context, const SuperadminProductsScreen()),
                      ),
                      _card(
                        context,
                        l10n.pick('Cafes', 'Cafenele'),
                        Icons.storefront_outlined,
                        AppColors.softBlue,
                        () => _open(context, const SuperadminLocationsScreen()),
                      ),
                      _card(
                        context,
                        l10n.pick('Records', 'Înregistrări'),
                        Icons.delete_sweep_outlined,
                        AppColors.softPurple,
                        () => _open(context, const SuperadminRecordsScreen()),
                      ),
                      _card(
                        context,
                        l10n.pick('Cafe\nadmin', 'Admin\ncafenea'),
                        Icons.admin_panel_settings_outlined,
                        AppColors.softGreen,
                        () => _open(context, const AdminDashboard()),
                      ),
                      _card(
                        context,
                        l10n.pick('Employee\napp', 'App\nangajat'),
                        Icons.badge_outlined,
                        AppColors.brandTurquoise,
                        () => _open(context, const EmployeeMainShell()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, L10n l10n) {
    return Container(
      padding: const EdgeInsets.only(
        top: 56,
        bottom: AppSpacing.xxxl,
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.warmGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppSpacing.xxxl),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pick('Superadmin', 'Superadmin'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.pick(
                    'Developers only — full data control',
                    'Doar developeri — control total pe date',
                  ),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
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
          const SizedBox(width: kLanguageSwitchReserve),
        ],
      ),
    );
  }

  Widget _card(
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

class _OverviewStrip extends StatelessWidget {
  const _OverviewStrip({required this.data, required this.l10n});

  final SuperadminOverview data;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.6)),
      ),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: [
          _chip(l10n.pick('Users', 'Utilizatori'), data.users),
          _chip(l10n.pick('Products', 'Produse'), data.products),
          _chip(l10n.pick('Cafes', 'Cafenele'), data.locations),
          _chip(l10n.pick('Shifts', 'Ture'), data.shifts),
        ],
      ),
    );
  }

  Widget _chip(String label, int value) {
    return Text(
      '$label $value',
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: AppColors.textDark,
      ),
    );
  }
}
