import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/widgets/admin_guard.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../locations/presentation/location_providers.dart';
import '../../scheduling/domain/scheduling_config_model.dart';
import '../../scheduling/presentation/scheduling_providers.dart';
import '../../scheduling/utils/scheduling_month_utils.dart';

final _adminSchedulingConfigProvider =
    StreamProvider.family<
      SchedulingConfigModel?,
      (DateTime month, String? location)
    >((ref, params) {
      return ref
          .read(schedulingConfigRepositoryProvider)
          .watchConfigForMonth(params.$1, location: params.$2);
    });

class OpenSchedulingScreen extends ConsumerStatefulWidget {
  const OpenSchedulingScreen({super.key});

  @override
  ConsumerState<OpenSchedulingScreen> createState() =>
      _OpenSchedulingScreenState();
}

class _OpenSchedulingScreenState extends ConsumerState<OpenSchedulingScreen> {
  late DateTime _selectedMonth;
  String? _selectedLocation;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month + 1, 1);
  }

  DateTime get _monthDate =>
      DateTime(_selectedMonth.year, _selectedMonth.month, 1);

  Future<void> _setEnabled(bool enabled) async {
    final admin = ref.read(authStateProvider).value;
    if (admin == null) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(schedulingConfigRepositoryProvider)
          .setSchedulingEnabled(
            year: _selectedMonth.year,
            month: _selectedMonth.month,
            location: _selectedLocation,
            enabled: enabled,
            adminUid: admin.uid,
          );
      ref.invalidate(_adminSchedulingConfigProvider);
      ref.invalidate(schedulingConfigForMonthProvider);

      if (enabled) {
        await ref
            .read(authRepositoryProvider)
            .sendNotificationToAllEmployees(
              title: 'Scheduling Opened!',
              body:
                  'Submit your availability for ${DateFormat('MMMM yyyy').format(_monthDate)}',
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Scheduling opened for ${DateFormat('MMMM yyyy').format(_monthDate)}'
                  : 'Scheduling closed for ${DateFormat('MMMM yyyy').format(_monthDate)}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(
      _adminSchedulingConfigProvider((_monthDate, _selectedLocation)),
    );
    final config = configAsync.value;
    final isOpen = config?.schedulingEnabled ?? false;
    final calendarLocked = !SchedulingMonthUtils.isMonthEditable(_monthDate);

    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            ScreenHeader(
              title: 'Open Scheduling',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMonthPicker(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildLocationPicker(),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildStatusCard(config, calendarLocked),
                    const SizedBox(height: AppSpacing.xxxl),
                    _buildActionButton(isOpen),
                    const SizedBox(height: AppSpacing.xxxl),
                    if (isOpen) _buildAvailabilityCalendar(),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Employees can submit availability only after you open scheduling. '
                      'Earlier submissions receive priority when capacity is limited (first-come-first-served).',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textDark.withValues(alpha: 0.55),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthPicker() {
    return AppSurface(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => setState(() {
              _selectedMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month - 1,
                1,
              );
            }),
            icon: const Icon(Icons.chevron_left, color: AppColors.primaryPink),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_monthDate),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          IconButton(
            onPressed: () => setState(() {
              _selectedMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month + 1,
                1,
              );
            }),
            icon: const Icon(Icons.chevron_right, color: AppColors.primaryPink),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPicker() {
    final locations = watchLocationNames(ref);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.6),
          width: 0.5,
        ),
        boxShadow: AppShadows.sm,
      ),
      child: DropdownButtonFormField<String?>(
        value: _selectedLocation,
        decoration: const InputDecoration(
          labelText: 'Location (optional)',
          border: InputBorder.none,
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All locations'),
          ),
          ...locations.map(
            (loc) => DropdownMenuItem(value: loc, child: Text(loc)),
          ),
        ],
        onChanged: _isSaving
            ? null
            : (v) => setState(() => _selectedLocation = v),
      ),
    );
  }

  Widget _buildStatusCard(SchedulingConfigModel? config, bool calendarLocked) {
    final enabled = config?.schedulingEnabled ?? false;
    Color bg;
    IconData icon;
    String title;
    String subtitle;

    if (calendarLocked) {
      bg = AppColors.textLight.withValues(alpha: 0.2);
      icon = Icons.lock;
      title = 'Month locked (calendar)';
      subtitle = 'Employees cannot edit this month after it starts.';
    } else if (enabled) {
      bg = AppColors.softGreen;
      icon = Icons.check_circle_outline;
      title = 'Scheduling is OPEN';
      subtitle = config?.enabledAt != null
          ? 'Opened ${DateFormat('MMM d, HH:mm').format(config!.enabledAt!)}'
          : 'Employees can submit availability.';
    } else {
      bg = AppColors.softYellow;
      icon = Icons.lock_clock;
      title = 'Scheduling is CLOSED';
      subtitle = 'Employees cannot submit until you open scheduling.';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 40,
            color: AppColors.textDark.withValues(alpha: 0.7),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(bool isOpen) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : () => _setEnabled(!isOpen),
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                  strokeCap: StrokeCap.round,
                ),
              )
            : Icon(
                isOpen ? Icons.lock_outline : Icons.lock_open,
                color: Colors.white,
              ),
        label: Text(
          isOpen ? 'Close scheduling' : 'Enable monthly scheduling',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOpen ? AppColors.textLight : AppColors.primaryPink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityCalendar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Availability Tracking',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ref.watch(allEmployeesProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (employees) => _buildCalendarGrid(employees),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(List<UserModel> employees) {
    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    final firstDayOfWeek = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    ).weekday;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.6),
          width: 0.5,
        ),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          _buildWeekdayHeader(),
          const SizedBox(height: AppSpacing.sm),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: firstDayOfWeek - 1 + daysInMonth,
            itemBuilder: (context, index) {
              if (index < firstDayOfWeek - 1) {
                return const SizedBox.shrink();
              }

              final day = index - (firstDayOfWeek - 1) + 1;
              final date = DateTime(
                _selectedMonth.year,
                _selectedMonth.month,
                day,
              );
              return _buildAvailabilityDayCell(date, employees);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAvailabilityDayCell(DateTime date, List<UserModel> employees) {
    return FutureBuilder<int>(
      future: _getTotalAvailabilityForDay(date, employees),
      builder: (context, availabilitySnapshot) {
        final availabilityCount = availabilitySnapshot.data ?? 0;
        final cellColor = availabilityCount > 0
            ? AppColors.brandGreen.withValues(alpha: 0.2)
            : AppColors.pureWhite;

        return Container(
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: availabilityCount > 0
                  ? AppColors.brandGreen.withValues(alpha: 0.5)
                  : AppColors.borderLight.withValues(alpha: 0.6),
              width: availabilityCount > 0 ? 1.0 : 0.5,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: availabilityCount > 0
                        ? AppColors.brandGreen
                        : AppColors.textDark,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$availabilityCount',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: availabilityCount > 0
                          ? AppColors.brandGreen
                          : AppColors.textLight,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<int> _getTotalAvailabilityForDay(
    DateTime date,
    List<UserModel> employees,
  ) async {
    int totalCount = 0;
    for (var employee in employees) {
      final availability = await ref
          .read(availabilityRepositoryProvider)
          .getForUserOnDay(employee.uid, date);
      if (availability != null) {
        totalCount++;
      }
    }
    return totalCount;
  }
}
