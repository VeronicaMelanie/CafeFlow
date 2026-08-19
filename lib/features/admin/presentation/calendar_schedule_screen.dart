import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/widgets/admin_guard.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../locations/presentation/location_providers.dart';
import '../../locations/utils/location_catalog.dart';
import '../../scheduling/domain/shift_model.dart';
import '../../scheduling/presentation/scheduling_providers.dart';
import '../../scheduling/presentation/widgets/roster_day_sheet.dart';

class CalendarScheduleScreen extends ConsumerStatefulWidget {
  const CalendarScheduleScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CalendarScheduleScreen> createState() =>
      _CalendarScheduleScreenState();
}

class _CalendarScheduleScreenState
    extends ConsumerState<CalendarScheduleScreen> {
  late String _selectedLocation;
  late DateTime _selectedMonth;
  int _reloadNonce = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Same default month as Schedule Manager (published schedules are usually next month).
    final focused = now.add(const Duration(days: 15));
    _selectedMonth = DateTime(focused.year, focused.month, 1);
    _selectedLocation = LocationCatalog.preferredDisplayName;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(locationsProvider, (_, next) {
      final locations = next.valueOrNull ?? const [];
      final names = LocationCatalog.names(locations);
      if (names.isEmpty) return;
      if (!names.contains(_selectedLocation)) {
        setState(() {
          _selectedLocation = LocationCatalog.preferredName(locations);
        });
      }
    });

    ref.watch(allEmployeesProvider);

    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            ScreenHeader(
              title: L10n.of(context).pick('Current schedule', 'Program curent'),
              onBack: () => Navigator.pop(context),
            ),
            _buildLocationSelector(),
            _buildMonthSelector(),
            Expanded(child: _buildCalendarGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSelector() {
    final names = watchLocationNames(ref);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
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
          children: [for (final name in names) _buildLocationItem(name)],
        ),
      ),
    );
  }

  Widget _buildLocationItem(String location) {
    final isSelected = _selectedLocation == location;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedLocation = location);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
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
            child: Text(
              location,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
                color: isSelected ? AppColors.brandGreen : AppColors.textLight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () {
              setState(
                () => _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                  1,
                ),
              );
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            DateFormat(
              'MMMM yyyy',
              L10n.of(context).isRo ? null : L10n.of(context).locale.languageCode,
            ).format(_selectedMonth),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(
                () => _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                  1,
                ),
              );
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Future<void> _openDaySheet(DateTime date) async {
    var loadingVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final employees = await ref.read(allEmployeesProvider.future);
      final locations = LocationCatalog.names(
        await ref.read(locationsProvider.future),
      );
      var dayShifts = await ref
          .read(shiftRepositoryProvider)
          .getShiftsOnDate(date);
      if (!mounted) return;
      Navigator.pop(context);
      loadingVisible = false;
      if (employees.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              L10n.of(context).pick(
                'No employees found.',
                'Nu s-au găsit angajați.',
              ),
            ),
          ),
        );
        return;
      }

      await showRosterDaySheet(
        context: context,
        date: date,
        locationNames: locations.isEmpty
            ? {for (final shift in dayShifts) shift.location}.toList()
            : locations,
        employees: employees,
        shiftsOfDay: () => dayShifts,
        onRemove: (shift) async {
          try {
            await ref.read(shiftRepositoryProvider).deleteShift(shift.id);
            dayShifts = [
              for (final item in dayShifts)
                if (item.id != shift.id) item,
            ];
            ref.invalidate(shiftsForMonthProvider);
            ref.invalidate(userShiftsProvider);
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(
              SnackBar(
                content: Text(
                  '${L10n.of(context).pick('Could not remove', 'Nu s-a putut scoate')}: $e',
                ),
              ),
            );
          }
        },
        onAdd: (location, employee) async {
          try {
            await ref
                .read(shiftRepositoryProvider)
                .createShift(
                  fullDayDraftShift(
                    employee: employee,
                    date: date,
                    location: location,
                    status: 'approved',
                  ),
                );
            dayShifts = await ref
                .read(shiftRepositoryProvider)
                .getShiftsOnDate(date);
            ref.invalidate(shiftsForMonthProvider);
            ref.invalidate(userShiftsProvider);
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(
              SnackBar(
                content: Text(
                  '${L10n.of(context).pick('Could not add', 'Nu s-a putut adăuga')}: $e',
                ),
              ),
            );
          }
        },
      );
      if (!mounted) return;
      setState(() => _reloadNonce++);
    } catch (e) {
      if (!mounted) return;
      if (loadingVisible) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            '${L10n.of(context).pick('Could not edit the day', 'Nu s-a putut edita ziua')}: $e',
          ),
        ),
      );
    }
  }

  Widget _buildCalendarGrid() {
    return StreamBuilder<List<ShiftModel>>(
      key: ValueKey(
        '$_selectedLocation-${_selectedMonth.year}-${_selectedMonth.month}-$_reloadNonce',
      ),
      stream: ref
          .read(shiftRepositoryProvider)
          .getShiftsForMonth(_selectedMonth, _selectedLocation),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(L10n.of(context).errorWith(snapshot.error!)));
        }
        if (!snapshot.hasData) {
          return const AppLoadingIndicator();
        }

        final shifts = snapshot.data!;
        return Column(
          children: [
            if (shifts.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
                child: Text(
                  L10n.of(context).pick(
                    'No published shifts for ${DateFormat('MMMM yyyy', L10n.of(context).isRo ? null : L10n.of(context).locale.languageCode).format(_selectedMonth)} at $_selectedLocation. Tap a day to assign 2 people, or publish from Schedule manager.',
                    'Nicio tură publicată pentru ${DateFormat('MMMM yyyy', L10n.of(context).isRo ? null : L10n.of(context).locale.languageCode).format(_selectedMonth)} la $_selectedLocation. Atinge o zi ca să pui 2 persoane sau publică din Manager program.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textLight,
                  ),
                ),
              ),
            Expanded(child: _buildCalendar(shifts)),
          ],
        );
      },
    );
  }

  Widget _buildCalendar(List<ShiftModel> shifts) {
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

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Text(
            L10n.of(context).pick(
              'Tap a day to change who works · max 2 per cafe',
              'Atinge o zi ca să schimbi cine lucrează · maxim 2 pe cafenea',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildWeekdayHeader(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.8,
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
                      (s) =>
                          s.date.day == day &&
                          s.date.month == _selectedMonth.month,
                    )
                    .toList();

                return _buildDayCell(date, dayShifts);
              },
            ),
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

  Widget _buildDayCell(DateTime date, List<ShiftModel> shifts) {
    final isUnderstaffed = shifts.length < 2;
    final cellColor = isUnderstaffed && shifts.isNotEmpty
        ? AppColors.brandRed.withValues(alpha: 0.15)
        : AppColors.pureWhite;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDaySheet(date),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isUnderstaffed && shifts.isNotEmpty
                  ? AppColors.brandRed.withValues(alpha: 0.5)
                  : AppColors.borderLight.withValues(alpha: 0.6),
              width: isUnderstaffed && shifts.isNotEmpty ? 1.0 : 0.5,
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
                    color: isUnderstaffed && shifts.isNotEmpty
                        ? AppColors.brandRed
                        : AppColors.textDark,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: shifts.take(2).map((shift) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandGreen.withValues(alpha: 0.2),
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
