import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/scheduling_config_repository.dart';
import '../domain/availability_model.dart';
import '../domain/shift_type.dart';
import '../utils/scheduling_month_utils.dart';
import 'availability_day_draft.dart';
import 'scheduling_providers.dart';
import 'widgets/shift_type_selection_sheet.dart';

class SubmitAvailabilityScreen extends ConsumerStatefulWidget {
  const SubmitAvailabilityScreen({super.key});

  @override
  ConsumerState<SubmitAvailabilityScreen> createState() =>
      _SubmitAvailabilityScreenState();
}

class _SubmitAvailabilityScreenState
    extends ConsumerState<SubmitAvailabilityScreen> {
  DateTime? _focusedDay;
  final Map<DateTime, DayAvailabilityDraft> _dayDrafts = {};
  bool _loadedFromServer = false;
  bool _isSaving = false;

  DateTime get _scheduleMonth {
    final fromProvider = ref.read(availabilityFocusedMonthProvider);
    return DateTime(fromProvider.year, fromProvider.month, 1);
  }

  static DateTime _normalizeDay(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  @override
  void initState() {
    super.initState();
    _focusedDay = ref.read(availabilityFocusedMonthProvider);
  }

  void _syncDraftsFromEntries(List<AvailabilityModel> entries) {
    if (_loadedFromServer) return;
    _loadedFromServer = true;
    _dayDrafts
      ..clear()
      ..addEntries(
        entries.map(
          (e) => MapEntry(
            _normalizeDay(e.date),
            DayAvailabilityDraft.fromModel(e),
          ),
        ),
      );
  }

  Future<void> _onDaySelected(DateTime day, bool canEdit) async {
    if (!canEdit || _isSaving) return;

    final normalized = _normalizeDay(day);
    final existingDraft = _dayDrafts[normalized];

    if (existingDraft == null) {
      final result = await showShiftTypeSelectionSheet(
        context: context,
        day: normalized,
      );
      if (result == null || !mounted) return;
      setState(() {
        _dayDrafts[normalized] = DayAvailabilityDraft.fromSelection(result);
      });
      return;
    }

    final outcome = await showAvailabilityEditSheet(
      context: context,
      day: normalized,
      initial: existingDraft.toSelectionResult(),
    );
    if (outcome == null || !mounted) return;

    setState(() {
      if (outcome.removed) {
        _dayDrafts.remove(normalized);
      } else if (outcome.selection != null) {
        _dayDrafts[normalized] = DayAvailabilityDraft.fromSelection(
          outcome.selection!,
          existingDocId: existingDraft.existingDocId,
        );
      }
    });
  }

  Future<void> _saveAvailability(
    List<AvailabilityModel> existingEntries,
    MonthSchedulingAccess access,
  ) async {
    if (!access.canEdit || _isSaving) return;

    final profile = ref.read(currentUserProvider).value;
    if (profile == null) return;

    final repo = ref.read(availabilityRepositoryProvider);

    setState(() => _isSaving = true);
    try {
      final actions = planAvailabilityPersist(
        drafts: _dayDrafts,
        existingEntries: existingEntries,
      );

      for (final action in actions) {
        switch (action.kind) {
          case AvailabilityPersistKind.delete:
            final existing = existingEntries.firstWhere(
              (entry) => entry.id == action.docId,
            );
            await repo.deleteForUserOnDay(profile.uid, existing.date);
          case AvailabilityPersistKind.skip:
            break;
          case AvailabilityPersistKind.create:
          case AvailabilityPersistKind.update:
            final day = action.day!;
            final draft = action.draft!;

            DateTime? customStart;
            DateTime? customEnd;
            if (draft.shiftType == AvailabilityShiftType.customHours) {
              customStart = draft.customStartDateTime(day);
              customEnd = draft.customEndDateTime(day);
              if (customStart == null || customEnd == null) {
                throw Exception(
                  'Custom hours require start and end time on ${DateFormat.MMMd().format(day)}.',
                );
              }
              final validationError = await repo.validatePartTimeHours(
                day: day,
                start: customStart,
                end: customEnd,
              );
              if (validationError != null) {
                throw Exception(validationError);
              }
            }

            await repo.saveAvailability(
              userId: profile.uid,
              day: day,
              shiftType: draft.shiftType,
              customStart: customStart,
              customEnd: customEnd,
            );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Availability saved'),
          backgroundColor: AppColors.primaryPink,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  _DayCellVisual _visualForDay(DateTime day) {
    final draft = _dayDrafts[_normalizeDay(day)];
    if (draft == null) return _DayCellVisual.none;
    if (draft.shiftType == AvailabilityShiftType.fullTime) {
      return _DayCellVisual.fullDay;
    }
    return _DayCellVisual.customHours;
  }

  @override
  Widget build(BuildContext context) {
    final scheduleMonth = _scheduleMonth;
    final access = ref.watch(monthSchedulingAccessProvider(scheduleMonth));
    final availabilityAsync =
        ref.watch(userAvailabilityForMonthProvider(scheduleMonth));
    final canEdit = access.canEdit;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: availabilityAsync.when(
        loading: () => const Scaffold(body: AppLoadingIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) {
          _syncDraftsFromEntries(entries);

          return Column(
            children: [
              ScreenHeader(
                title: 'Availability',
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(canEdit),
                      const SizedBox(height: AppSpacing.xxl),
                      _buildCalendarCard(
                        scheduleMonth: scheduleMonth,
                        canEdit: canEdit,
                      ),
                    ],
                  ),
                ),
              ),
              _buildSaveButton(
                entries: entries,
                access: access,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(bool canEdit) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.softPink.withValues(alpha: canEdit ? 0.55 : 0.3),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: canEdit ? AppColors.primaryPink : AppColors.textLight,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              canEdit
                  ? 'Tap a day to set Full Day or Custom Hours availability. Green = full day, lighter green = custom hours.'
                  : 'You can view your submitted days. Editing is disabled for this month.',
              style: TextStyle(
                color: AppColors.textDark.withValues(alpha: canEdit ? 0.8 : 0.55),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard({
    required DateTime scheduleMonth,
    required bool canEdit,
  }) {
    final firstDay = SchedulingMonthUtils.monthStart(scheduleMonth);
    final lastDay = DateTime(scheduleMonth.year, scheduleMonth.month + 1, 0);
    final focused = _focusedDay ?? firstDay;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppSpacing.xxxl),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.6),
          width: 0.5,
        ),
        boxShadow: AppShadows.md,
      ),
      child: TableCalendar(
        firstDay: firstDay,
        lastDay: lastDay,
        focusedDay: focused,
        enabledDayPredicate: (_) => canEdit,
        selectedDayPredicate: (day) =>
            _dayDrafts.containsKey(_normalizeDay(day)),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() => _focusedDay = focusedDay);
          _onDaySelected(selectedDay, canEdit);
        },
        onPageChanged: (focusedDay) {
          setState(() => _focusedDay = focusedDay);
        },
        calendarBuilders: CalendarBuilders(
          selectedBuilder: (context, day, focusedDay) {
            return _DayCell(
              day: day.day,
              visual: _visualForDay(day),
              enabled: canEdit,
            );
          },
          defaultBuilder: (context, day, focusedDay) {
            final visual = _visualForDay(day);
            if (visual == _DayCellVisual.none) {
              return _DayCell(day: day.day, enabled: canEdit);
            }
            return null;
          },
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: AppColors.primaryPink,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: AppColors.primaryPink,
          ),
        ),
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(
            color: AppColors.primaryPink,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: AppColors.primaryPink.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: AppColors.primaryPink,
            fontWeight: FontWeight.bold,
          ),
          weekendTextStyle: const TextStyle(color: AppColors.accentPink),
        ),
      ),
    );
  }

  Widget _buildSaveButton({
    required List<AvailabilityModel> entries,
    required MonthSchedulingAccess access,
  }) {
    final canSave = access.canEdit && !_isSaving;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      child: AppButton(
        text: _isSaving ? 'Saving...' : 'Save & Done',
        onPressed: canSave ? () => _saveAvailability(entries, access) : null,
        isLoading: _isSaving,
      ),
    );
  }
}

enum _DayCellVisual { none, fullDay, customHours }

class _DayCell extends StatelessWidget {
  final int day;
  final _DayCellVisual visual;
  final bool enabled;

  const _DayCell({
    required this.day,
    this.visual = _DayCellVisual.none,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    switch (visual) {
      case _DayCellVisual.none:
        return Center(
          child: Text(
            '$day',
            style: TextStyle(
              color: enabled ? AppColors.textDark : AppColors.textLight,
            ),
          ),
        );
      case _DayCellVisual.fullDay:
        return Center(
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primaryPink,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$day',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      case _DayCellVisual.customHours:
        return Center(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.softPink.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryPink,
                    width: 2,
                  ),
                ),
                child: Text(
                  '$day',
                  style: const TextStyle(
                    color: AppColors.primaryPink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryPink,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}
