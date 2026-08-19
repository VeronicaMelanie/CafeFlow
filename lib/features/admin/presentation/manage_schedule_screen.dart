import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/utils/location_color_utils.dart';
import '../../../core/widgets/admin_guard.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../locations/presentation/location_providers.dart';
import '../../locations/utils/location_catalog.dart';
import '../../scheduling/data/scheduling_service.dart';
import '../../scheduling/domain/availability_model.dart';
import '../../scheduling/domain/shift_model.dart';
import '../../scheduling/presentation/scheduling_providers.dart';
import '../../scheduling/presentation/widgets/roster_day_sheet.dart';

class ManageScheduleScreen extends ConsumerStatefulWidget {
  const ManageScheduleScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ManageScheduleScreen> createState() =>
      _ManageScheduleScreenState();
}

class _ManageScheduleScreenState extends ConsumerState<ManageScheduleScreen> {
  List<ShiftModel> _draftShifts = [];
  List<AvailabilityModel> _availability = [];
  bool _isGenerating = false;
  DateTime _selectedMonth = DateTime.now().add(const Duration(days: 15));

  SchedulingService get _schedulingService =>
      ref.read(schedulingServiceProvider);

  Future<void> _generateDraft() async {
    if (_draftShifts.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final l10n = L10n.of(context);
          return AlertDialog(
            title: Text(l10n.pick('Generate again?', 'Generează din nou?')),
            content: Text(
              l10n.pick(
                'This replaces the current draft. Day-by-day changes will be lost.',
                'Asta înlocuiește ciorna actuală. Modificările pe zile se pierd.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.pick('Cancel', 'Anulează')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.pick('Generate', 'Generează')),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _isGenerating = true);
    try {
      final shifts = await _schedulingService.generateDraftSchedule(
        _selectedMonth,
      );
      var availability = <AvailabilityModel>[];
      try {
        availability = await ref
            .read(availabilityRepositoryProvider)
            .getAvailabilityForMonth(_selectedMonth);
      } catch (_) {
        availability = const [];
      }
      setState(() {
        _draftShifts = shifts;
        _availability = availability;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L10n.of(context).errorWith(e))));
    }
  }

  Future<void> _publish() async {
    if (_draftShifts.isEmpty) return;

    setState(() => _isGenerating = true);
    try {
      await _schedulingService.publishSchedule(_draftShifts);
      if (!mounted) return;
      ref.invalidate(shiftsForMonthProvider);
      ref.invalidate(userShiftsProvider);
      final l10n = L10n.of(context);
      final monthLabel = DateFormat(
        'MMMM yyyy',
        l10n.isRo ? null : l10n.locale.languageCode,
      ).format(_selectedMonth);
      unawaited(
        ref
            .read(authRepositoryProvider)
            .sendNotificationToAllEmployees(
              title: l10n.pick('Schedule published', 'Program publicat'),
              body: l10n.pick(
                'Your schedule for $monthLabel is ready.',
                'Programul tău pentru $monthLabel e gata.',
              ),
            ),
      );
      setState(() {
        _draftShifts = [];
        _availability = [];
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            L10n.of(context).pick(
              'Schedule published! 📅',
              'Programul a fost publicat! 📅',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.softGreen,
        ),
      );
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L10n.of(context).errorWith(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(allEmployeesProvider);
    ref.watch(locationsProvider);
    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            ScreenHeader(
              title: L10n.of(context).pick('Schedule manager', 'Manager program'),
              onBack: () => Navigator.pop(context),
            ),
            _buildControlBar(),
            Expanded(
              child: _isGenerating
                  ? const AppLoadingIndicator()
                  : _draftShifts.isEmpty
                  ? _buildEmptyState()
                  : _buildDraftCalendar(),
            ),
            if (_draftShifts.isNotEmpty && !_isGenerating) _buildActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    final l10n = L10n.of(context);
    return Container(
      margin: const EdgeInsets.all(AppSpacing.xl),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.6),
          width: 0.5,
        ),
        boxShadow: AppShadows.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.pick('Selected month', 'Luna selectată'),
                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              Text(
                DateFormat('MMMM yyyy', l10n.isRo ? null : l10n.locale.languageCode)
                    .format(_selectedMonth),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.primaryPink,
                ),
              ),
              if (_draftShifts.isNotEmpty)
                Text(
                  l10n.pick(
                    '${_draftShifts.length} shifts · ${_uniquePeopleCount()} people',
                    '${_draftShifts.length} ture · ${_uniquePeopleCount()} persoane',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
            ],
          ),
          ElevatedButton(
            onPressed: _isGenerating ? null : _generateDraft,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.softPink,
              foregroundColor: AppColors.primaryPink,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
            child: Text(l10n.pick('Generate schedule', 'Generează program')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = L10n.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: AppColors.textLight.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.pick('No draft yet', 'Nicio ciornă încă'),
            style: const TextStyle(color: AppColors.textLight, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.huge),
            child: Text(
              l10n.pick(
                'Availability is unlimited. Generation picks 2 people per cafe per day. Then tap a day to change names before you publish.',
                'Disponibilitatea e nelimitată. Generarea alege 2 persoane pe cafenea pe zi. Apoi atinge o zi ca să schimbi numele înainte să publici.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLight, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = L10n.of(context);
        return AlertDialog(
          title: Text(l10n.pick('Clear the draft?', 'Golești ciorna?')),
          content: Text(
            l10n.pick(
              'The unpublished schedule for this month will be deleted.',
              'Programul nepublicat pentru luna asta va fi șters.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.pick('Cancel', 'Anulează')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.pick('Clear', 'Golește')),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      setState(() {
        _draftShifts = [];
        _availability = [];
      });
    }
  }

  int _uniquePeopleCount() {
    return {for (final shift in _draftShifts) shift.userId}.length;
  }

  List<AvailabilityModel> _availableOn(DateTime date) {
    return _availability
        .where(
          (entry) =>
              entry.date.year == date.year &&
              entry.date.month == date.month &&
              entry.date.day == date.day,
        )
        .toList();
  }

  Set<String> _availableUserIdsOn(DateTime date) {
    return {for (final entry in _availableOn(date)) entry.userId};
  }

  int _unplacedCount(DateTime date) {
    final assigned = {for (final shift in _shiftsOn(date)) shift.userId};
    return _availableUserIdsOn(date).difference(assigned).length;
  }

  int _overflowDayCount() {
    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    var count = 0;
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      if (_unplacedCount(date) > 0) count++;
    }
    return count;
  }

  List<ShiftModel> _shiftsOn(DateTime date) {
    return _draftShifts
        .where(
          (shift) =>
              shift.date.year == date.year &&
              shift.date.month == date.month &&
              shift.date.day == date.day,
        )
        .toList()
      ..sort((a, b) {
        final byLocation = a.location.compareTo(b.location);
        if (byLocation != 0) return byLocation;
        return a.startTime.compareTo(b.startTime);
      });
  }

  Widget _buildDraftCalendar() {
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Text(
            L10n.of(context).pick(
              'Yellow days have extra people who wanted the day. Tap to place or swap · max 2 per cafe',
              'Zilele galbene au oameni în plus care au vrut ziua. Atinge ca să pui sau să schimbi · maxim 2 pe cafenea',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
          if (_overflowDayCount() > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              L10n.of(context).pick(
                '${_overflowDayCount()} days still have people waiting',
                '${_overflowDayCount()} zile mai au oameni pe listă de așteptare',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.brandMustard,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _buildWeekdayHeader(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.72,
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
                return _buildDayCell(date, _shiftsOn(date), _unplacedCount(date));
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

  Widget _buildDayCell(
    DateTime date,
    List<ShiftModel> shifts,
    int unplacedCount,
  ) {
    final hasShifts = shifts.isNotEmpty;
    final hasWaitlist = unplacedCount > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDaySheet(date),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: hasWaitlist
                ? AppColors.brandMustard.withValues(alpha: 0.16)
                : hasShifts
                ? AppColors.brandGreen.withValues(alpha: 0.06)
                : AppColors.pureWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasWaitlist
                  ? AppColors.brandMustard.withValues(alpha: 0.7)
                  : hasShifts
                  ? AppColors.brandGreen.withValues(alpha: 0.35)
                  : AppColors.borderLight.withValues(alpha: 0.6),
              width: hasWaitlist ? 1.2 : 0.5,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 2, right: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: hasShifts || hasWaitlist
                              ? AppColors.textDark
                              : AppColors.textLight,
                        ),
                      ),
                    ),
                    if (hasWaitlist)
                      Text(
                        '+$unplacedCount',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandMustard,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  child: Column(
                    children: [
                      for (final shift in shifts.take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 1),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: LocationColorUtils.backgroundFor(
                                shift.location,
                              ).withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              shift.userName.split(' ').first,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: LocationColorUtils.foregroundFor(
                                  shift.location,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (shifts.length > 3)
                        Text(
                          '+${shifts.length - 3}',
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textLight,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDaySheet(DateTime date) {
    final locations = LocationCatalog.names(
      ref.read(locationsProvider).valueOrNull ?? const [],
    );
    final employees = ref.read(allEmployeesProvider).valueOrNull ?? const [];
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            L10n.of(context).pick(
              'The team list is still loading. Try again.',
              'Lista echipei încă se încarcă. Încearcă din nou.',
            ),
          ),
        ),
      );
      return;
    }
    showRosterDaySheet(
      context: context,
      date: date,
      locationNames: locations.isEmpty
          ? {for (final shift in _draftShifts) shift.location}.toList()
          : locations,
      employees: employees,
      availableUserIds: _availableUserIdsOn(date),
      shiftsOfDay: () => _shiftsOn(date),
      onRemove: (shift) async {
        setState(() {
          _draftShifts = [
            for (final item in _draftShifts)
              if (item.id != shift.id) item,
          ];
        });
      },
      onAdd: (location, employee) async {
        setState(() {
          _draftShifts = [
            ..._draftShifts,
            fullDayDraftShift(
              employee: employee,
              date: date,
              location: location,
              id: 'draft_${DateTime.now().microsecondsSinceEpoch}',
            ),
          ];
        });
      },
    );
  }

  Widget _buildActionBar() {
    final l10n = L10n.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        boxShadow: AppShadows.lg,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearDraft,
                  child: Text(l10n.pick('Clear draft', 'Golește ciorna')),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton(
                  onPressed: _generateDraft,
                  child: Text(l10n.pick('Generate again', 'Generează din nou')),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.green, Color(0xFF4CAF50)],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              boxShadow: AppShadows.coloredGlow(Colors.green),
            ),
            child: ElevatedButton(
              onPressed: _publish,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
              ),
              child: Text(
                l10n.pick('Publish schedule', 'Publică programul'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
