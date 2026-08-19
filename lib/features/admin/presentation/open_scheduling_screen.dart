import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
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
  bool _isReminding = false;

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

      if (!mounted) return;
      final l10n = L10n.of(context);
      final monthLabel = DateFormat(
        'MMMM yyyy',
        l10n.isRo ? null : l10n.locale.languageCode,
      ).format(_monthDate);

      if (enabled) {
        await ref
            .read(authRepositoryProvider)
            .sendNotificationToAllEmployees(
              title: l10n.pick('Scheduling is open!', 'Programarea e deschisă!'),
              body: l10n.pick(
                'Submit your availability for $monthLabel',
                'Completează disponibilitatea pentru $monthLabel',
              ),
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? l10n.pick(
                      'Scheduling is open for $monthLabel',
                      'Programarea e deschisă pentru $monthLabel',
                    )
                  : l10n.pick(
                      'Scheduling is closed for $monthLabel',
                      'Programarea e închisă pentru $monthLabel',
                    ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.of(context).errorWith(e)),
            backgroundColor: Colors.redAccent,
          ),
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
              title: L10n.of(context).pick(
                'Open scheduling',
                'Deschide programarea',
              ),
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
                    const SizedBox(height: AppSpacing.xl),
                    _buildRemindButton(),
                    const SizedBox(height: AppSpacing.xxxl),
                    _buildActionButton(isOpen),
                    const SizedBox(height: AppSpacing.xxxl),
                    if (isOpen ||
                        SchedulingMonthUtils.isAvailabilityWindowOpen(
                          _monthDate,
                        ))
                      _buildAvailabilityCalendar(),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      L10n.of(context).pick(
                        'Availability for next month opens automatically on the 20th and closes on the 30th (last day in February). You can close it earlier if needed. First submissions get priority when the cafe is already filled by two people.',
                        'Disponibilitatea pentru luna următoare se deschide automat pe 20 și se închide pe 30 (ultima zi în februarie). Poți să o închizi mai devreme dacă e nevoie. Primele trimiteri au prioritate când cafeneaua e deja ocupată de două persoane.',
                      ),
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
            DateFormat(
              'MMMM yyyy',
              L10n.of(context).isRo ? null : L10n.of(context).locale.languageCode,
            ).format(_monthDate),
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
    final l10n = L10n.of(context);
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
        decoration: InputDecoration(
          labelText: l10n.pick('Location (optional)', 'Locație (opțional)'),
          border: InputBorder.none,
        ),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text(l10n.pick('All locations', 'Toate locațiile')),
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
    final l10n = L10n.of(context);
    final locale = l10n.isRo ? null : l10n.locale.languageCode;
    final enabled = config?.schedulingEnabled ?? false;
    Color bg;
    IconData icon;
    String title;
    String subtitle;

    if (calendarLocked) {
      bg = AppColors.textLight.withValues(alpha: 0.2);
      icon = Icons.lock;
      title = l10n.pick('Month is locked (calendar)', 'Luna e blocată (calendar)');
      subtitle = l10n.pick(
        'Employees can no longer edit the month after it has started.',
        'Angajații nu mai pot edita luna după ce a început.',
      );
    } else if (enabled) {
      bg = AppColors.softGreen;
      icon = Icons.check_circle_outline;
      title = l10n.pick('Scheduling is OPEN', 'Programarea e DESCHISĂ');
      subtitle = config?.enabledAt != null
          ? l10n.pick(
              'Opened ${DateFormat('MMM d, HH:mm', locale).format(config!.enabledAt!)}',
              'Deschisă ${DateFormat('MMM d, HH:mm', locale).format(config!.enabledAt!)}',
            )
          : l10n.pick(
              'Employees can submit availability.',
              'Angajații pot trimite disponibilitatea.',
            );
    } else {
      final window = SchedulingMonthUtils.availabilityWindowFor(_monthDate);
      final autoOpen = SchedulingMonthUtils.isAvailabilityWindowOpen(
        _monthDate,
      );
      bg = autoOpen ? AppColors.softGreen : AppColors.softYellow;
      icon = autoOpen ? Icons.check_circle_outline : Icons.lock_clock;
      title = autoOpen
          ? l10n.pick('Window is OPEN (20–30)', 'Fereastra e DESCHISĂ (20–30)')
          : l10n.pick('Outside the 20–30 window', 'În afara ferestrei 20–30');
      subtitle = autoOpen
          ? l10n.pick(
              'Employees can submit until ${DateFormat('d MMM', locale).format(window.end)}. Close below only if you want to block earlier.',
              'Angajații pot trimite până pe ${DateFormat('d MMM', locale).format(window.end)}. Închide mai jos doar dacă vrei să blochezi mai devreme.',
            )
          : l10n.pick(
              'Opens ${DateFormat('d MMM', locale).format(window.start)}–${DateFormat('d MMM', locale).format(window.end)}. In February it closes on the last day of the month.',
              'Se deschide ${DateFormat('d MMM', locale).format(window.start)}–${DateFormat('d MMM', locale).format(window.end)}. În februarie se închide în ultima zi a lunii.',
            );
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

  Widget _buildRemindButton() {
    return OutlinedButton.icon(
      onPressed: _isReminding ? null : _remindMissing,
      icon: _isReminding
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.notifications_active_outlined),
      label: Text(
        L10n.of(context).pick(
          'Remind those who haven’t submitted',
          'Amintește cui nu a trimis',
        ),
      ),
    );
  }

  Future<void> _remindMissing() async {
    setState(() => _isReminding = true);
    try {
      final employees = await ref
          .read(authRepositoryProvider)
          .getAllEmployees()
          .first;
      final submitted = await ref
          .read(availabilityRepositoryProvider)
          .getAvailabilityForMonth(_monthDate);
      final whoSubmitted = {for (final row in submitted) row.userId};
      final missing = [
        for (final employee in employees)
          if (!whoSubmitted.contains(employee.uid)) employee.uid,
      ];
      if (missing.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.of(context).pick(
                'Everyone submitted at least one day.',
                'Toată lumea a trimis măcar o zi.',
              ),
            ),
          ),
        );
        return;
      }
      final l10n = L10n.of(context);
      final monthLabel = DateFormat(
        'MMMM yyyy',
        l10n.isRo ? null : l10n.locale.languageCode,
      ).format(_monthDate);
      await ref
          .read(authRepositoryProvider)
          .sendNotificationToUids(
            uids: missing,
            title: l10n.pick(
              'Reminder: submit your availability',
              'Amintește: completează disponibilitatea',
            ),
            body: l10n.pick(
              'Please mark the days you can work in $monthLabel.',
              'Te rog marchează zilele în care poți lucra în $monthLabel.',
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pick(
              'Reminded ${missing.length} people.',
              'Am amintit ${missing.length} persoane.',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.of(context).errorWith(e)),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isReminding = false);
    }
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
          isOpen
              ? L10n.of(context).pick('Close scheduling', 'Închide programarea')
              : L10n.of(context).pick(
                  'Open monthly scheduling',
                  'Deschide programarea lunară',
                ),
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
          L10n.of(context).pick(
            'Availability tracking',
            'Urmărire disponibilitate',
          ),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ref
            .watch(allEmployeesProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text(L10n.of(context).errorWith(error))),
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
    final l10n = L10n.of(context);
    return Row(
      children: [
        for (var i = 1; i <= 7; i++)
          Expanded(
            child: Center(
              child: Text(
                l10n.weekdayShort(i),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textLight,
                ),
              ),
            ),
          ),
      ],
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
