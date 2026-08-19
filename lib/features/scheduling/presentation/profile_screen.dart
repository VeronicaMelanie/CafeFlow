import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/pwa/pwa_responsive.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/employee_bottom_nav_bar.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/presentation/auth_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final NotificationService _notifications = NotificationService();
  bool _shiftReminders = true;
  bool _scheduleUpdates = true;
  bool _vacationStatus = true;
  bool _soundEnabled = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    await _notifications.init();
    setState(() {
      _shiftReminders = _notifications.shiftRemindersEnabled;
      _scheduleUpdates = _notifications.scheduleUpdatesEnabled;
      _vacationStatus = _notifications.vacationStatusEnabled;
      _soundEnabled = _notifications.soundEnabled;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final l10n = L10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: userAsync.when(
        data: (user) {
          if (user == null) return Center(child: Text(l10n.notSignedIn()));
          if (!_loaded) {
            return const AppLoadingIndicator();
          }

          return Column(
            children: [
              ScreenHeader(
                title: l10n.pick('Profile', 'Profil'),
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
                    children: [
                      _buildProfileCard(user, l10n),
                      const SizedBox(height: 24),
                      _buildNotificationSettings(l10n),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              ref.read(authRepositoryProvider).signOut(),
                          icon: const Icon(Icons.logout, color: AppColors.primaryPink),
                          label: Text(l10n.pick('Log out', 'Deconectare')),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const AppLoadingIndicator(),
        error: (e, st) => Center(child: Text(l10n.errorWith(e))),
      ),
    );
  }

  Widget _buildProfileCard(dynamic user, L10n l10n) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              gradient: AppColors.headerGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: const TextStyle(fontSize: 14, color: AppColors.textLight),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildProfileItem(l10n.pick('Role', 'Rol'), l10n.roleLabel(user.role), AppColors.softPink),
              _buildProfileItem(l10n.pick('Type', 'Tip'), l10n.workTypeLabel(user.workType), AppColors.softYellow),
              _buildProfileItem(l10n.pick('Location', 'Locație'), user.primaryLocation, AppColors.softGreen),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.softBlue.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.pick('Monthly target', 'Țintă lunară'),
                  style: const TextStyle(fontSize: 14, color: AppColors.textLight),
                ),
                Text(
                  '${user.monthlyTargetHours} ${l10n.pick('hours', 'ore')}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const Icon(Icons.person_outline, size: 16, color: AppColors.textDark),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
      ],
    );
  }

  Widget _buildNotificationSettings(L10n l10n) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pick('Notifications', 'Notificări'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildToggle(
            title: l10n.pick('Shift reminders', 'Reminder ture'),
            subtitle: l10n.pick(
              '1 day before each approved shift',
              'Cu 1 zi înainte de fiecare tură aprobată',
            ),
            value: _shiftReminders,
            onChanged: (v) async {
              await _notifications.setShiftReminders(v);
              setState(() => _shiftReminders = v);
            },
          ),
          _buildToggle(
            title: l10n.pick('Schedule updates', 'Actualizări program'),
            subtitle: l10n.pick(
              'When a new schedule is published',
              'Când se publică un program nou',
            ),
            value: _scheduleUpdates,
            onChanged: (v) async {
              await _notifications.setScheduleUpdates(v);
              setState(() => _scheduleUpdates = v);
            },
          ),
          _buildToggle(
            title: l10n.pick('Vacation status', 'Status concediu'),
            subtitle: l10n.pick(
              'Approval or rejection of requests',
              'Aprobare sau respingere a cererilor',
            ),
            value: _vacationStatus,
            onChanged: (v) async {
              await _notifications.setVacationStatus(v);
              setState(() => _vacationStatus = v);
            },
          ),
          _buildToggle(
            title: l10n.pick('Notification sounds', 'Sunete notificări'),
            subtitle: l10n.pick(
              'Play a sound for notifications',
              'Redă sunet la notificări',
            ),
            value: _soundEnabled,
            onChanged: (v) async {
              await _notifications.setSoundEnabled(v);
              setState(() => _soundEnabled = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.offWhite,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: AppColors.borderLight.withValues(alpha: 0.8),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.primaryPink.withValues(alpha: 0.5),
              activeThumbColor: AppColors.primaryPink,
            ),
          ],
        ),
      ),
    );
  }
}
