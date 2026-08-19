import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/pwa/pwa_responsive.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/employee_bottom_nav_bar.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../locations/presentation/location_providers.dart';
import '../../locations/utils/location_catalog.dart';
import '../domain/shift_model.dart';
import 'scheduling_providers.dart';
import 'widgets/team_roster_day_sheet.dart';

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final location = ref.watch(selectedLocationProvider);
    final currentUid = ref.watch(currentUserProvider).value?.uid;

    ref.listen(locationsProvider, (_, next) {
      final names = LocationCatalog.names(next.valueOrNull ?? const []);
      if (names.isEmpty) return;
      if (!names.contains(location)) {
        ref.read(selectedLocationProvider.notifier).state =
            LocationCatalog.preferredName(next.valueOrNull ?? const []);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Column(
        children: [
          ScreenHeader(
            title: l10n.pick("Who's working", 'Cine lucrează'),
            subtitle: l10n.pick(
              'Published roster for the team',
              'Programul publicat al echipei',
            ),
            topPadding: PwaResponsive.topSafePadding(context) + AppSpacing.lg,
          ),
          _buildLocationSelector(location),
          _buildMonthSelector(l10n),
          Expanded(
            child: _buildCalendarGrid(location, currentUid),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSelector(String selected) {
    final names = watchLocationNames(ref);
    if (names.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Container(
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
            for (final name in names)
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      ref.read(selectedLocationProvider.notifier).state = name,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: selected == name
                          ? AppColors.pureWhite
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusPill - 3),
                      border: selected == name
                          ? Border.all(
                              color: AppColors.brandGreen.withValues(alpha: 0.3),
                              width: 0.5,
                            )
                          : null,
                      boxShadow: selected == name ? AppShadows.xs : null,
                    ),
                    child: Center(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: selected == name
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 13,
                          color: selected == name
                              ? AppColors.brandGreen
                              : AppColors.textLight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector(L10n l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                  1,
                );
              });
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            DateFormat(
              'MMMM yyyy',
              l10n.isRo ? null : l10n.locale.languageCode,
            ).format(_selectedMonth),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                  1,
                );
              });
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(String location, String? currentUid) {
    return StreamBuilder<List<ShiftModel>>(
      key: ValueKey(
        '$location-${_selectedMonth.year}-${_selectedMonth.month}',
      ),
      stream: ref
          .read(shiftRepositoryProvider)
          .getShiftsForMonth(_selectedMonth, location),
      builder: (context, snapshot) {
        final l10n = L10n.of(context);
        if (snapshot.hasError) {
          return Center(child: Text(l10n.errorWith(snapshot.error!)));
        }
        if (!snapshot.hasData) {
          return const AppLoadingIndicator();
        }

        final shifts = snapshot.data!
            .where((shift) => shift.status == 'approved')
            .toList();

        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            EmployeeBottomNavMetrics.contentBottomPadding(context),
          ),
          child: Column(
            children: [
              Text(
                l10n.pick(
                  'Tap a day to see who is working',
                  'Atinge o zi ca să vezi cine lucrează',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              if (shifts.isEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.pick(
                    'No published shifts for this month at $location yet.',
                    'Nicio tură publicată luna aceasta la $location.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textLight,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _buildWeekdayHeader(l10n),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: _buildCalendar(shifts, currentUid),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeekdayHeader(L10n l10n) {
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

  Widget _buildCalendar(List<ShiftModel> shifts, String? currentUid) {
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

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.78,
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
        final dayShifts = shifts
            .where(
              (s) => s.date.day == day && s.date.month == _selectedMonth.month,
            )
            .toList();

        return _DayCell(
          date: date,
          shifts: dayShifts,
          currentUserId: currentUid,
          onTap: () => _openDay(date),
        );
      },
    );
  }

  Future<void> _openDay(DateTime date) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final dayShifts =
          await ref.read(shiftRepositoryProvider).getShiftsOnDate(date);
      final locations = watchLocationNames(ref);
      final currentUid = ref.read(currentUserProvider).value?.uid;
      if (!mounted) return;
      Navigator.pop(context);
      await showTeamRosterDaySheet(
        context: context,
        date: date,
        shifts: dayShifts,
        locationNames: locations.isEmpty
            ? {for (final shift in dayShifts) shift.location}.toList()
            : locations,
        currentUserId: currentUid,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).errorWith(e))),
      );
    }
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.shifts,
    required this.currentUserId,
    required this.onTap,
  });

  final DateTime date;
  final List<ShiftModel> shifts;
  final String? currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isMine =
        currentUserId != null && shifts.any((s) => s.userId == currentUserId);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: isMine
                ? AppColors.brandMustard.withValues(alpha: 0.2)
                : AppColors.pureWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isToday
                  ? AppColors.brandGreen
                  : AppColors.borderLight.withValues(alpha: 0.8),
              width: isToday ? 1.6 : 0.5,
            ),
            boxShadow: AppShadows.xs,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isToday ? AppColors.brandGreen : AppColors.textDark,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: shifts.take(2).map((shift) {
                      final mine = shift.userId == currentUserId;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: mine
                                ? AppColors.brandMustard.withValues(alpha: 0.45)
                                : AppColors.brandGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            shift.userName.split(' ').first,
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
