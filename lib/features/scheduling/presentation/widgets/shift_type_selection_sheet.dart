import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/widgets/interactive_scale.dart';
import '../../domain/shift_type.dart';
import '../../utils/scheduling_month_utils.dart';

/// Result returned when the employee confirms availability for a day.
class ShiftTypeSelectionResult {
  final AvailabilityShiftType shiftType;
  final TimeOfDay? start;
  final TimeOfDay? end;

  const ShiftTypeSelectionResult({
    required this.shiftType,
    this.start,
    this.end,
  });
}

/// Outcome when editing an existing availability day.
class AvailabilityDayEditOutcome {
  final bool removed;
  final ShiftTypeSelectionResult? selection;

  const AvailabilityDayEditOutcome.removed()
      : removed = true,
        selection = null;

  const AvailabilityDayEditOutcome.confirmed(ShiftTypeSelectionResult result)
      : removed = false,
        selection = result;
}

String _formatDayLabel(DateTime day) =>
    DateFormat('EEEE, MMM d').format(day);

String _formatTimeRange(ShiftTypeSelectionResult initial) {
  if (initial.shiftType == AvailabilityShiftType.fullTime) {
    return '07:00 – 18:00 (Full Day)';
  }
  final start = initial.start!;
  final end = initial.end!;
  final startStr =
      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  final endStr =
      '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  return '$startStr – $endStr (Custom Hours)';
}

/// Edit sheet for a day that already has availability.
Future<AvailabilityDayEditOutcome?> showAvailabilityEditSheet({
  required BuildContext context,
  required DateTime day,
  required ShiftTypeSelectionResult initial,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AvailabilityEditSheet(day: day, initial: initial),
  );

  if (action == null || !context.mounted) return null;
  if (action == 'remove') return const AvailabilityDayEditOutcome.removed();

  if (action == 'change') {
    if (!context.mounted) return null;
    final updated = await showShiftTypeSelectionSheet(
      context: context,
      day: day,
      initial: initial,
    );
    if (updated == null) return null;
    return AvailabilityDayEditOutcome.confirmed(updated);
  }

  return null;
}

/// Bottom sheet: choose Full Day or Custom hours.
Future<ShiftTypeSelectionResult?> showShiftTypeSelectionSheet({
  required BuildContext context,
  required DateTime day,
  ShiftTypeSelectionResult? initial,
}) async {
  final choice = await showModalBottomSheet<AvailabilityShiftType>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AvailabilityChoiceSheet(day: day),
  );

  if (choice == null || !context.mounted) return null;
  if (choice == AvailabilityShiftType.fullTime) {
    return const ShiftTypeSelectionResult(
      shiftType: AvailabilityShiftType.fullTime,
    );
  }

  final customInitialStart =
      initial?.shiftType == AvailabilityShiftType.customHours
          ? initial!.start
          : null;
  final customInitialEnd =
      initial?.shiftType == AvailabilityShiftType.customHours
          ? initial!.end
          : null;

  if (!context.mounted) return null;

  final custom = await showModalBottomSheet<ShiftTypeSelectionResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CustomHoursSheet(
      day: day,
      initialStart: customInitialStart,
      initialEnd: customInitialEnd,
    ),
  );
  return custom;
}

class _AvailabilityEditSheet extends StatefulWidget {
  final DateTime day;
  final ShiftTypeSelectionResult initial;

  const _AvailabilityEditSheet({
    required this.day,
    required this.initial,
  });

  @override
  State<_AvailabilityEditSheet> createState() => _AvailabilityEditSheetState();
}

class _AvailabilityEditSheetState extends State<_AvailabilityEditSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            boxShadow: AppShadows.lg,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.md,
                AppSpacing.xxl,
                AppSpacing.xxl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _formatDayLabel(widget.day),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current: ${_formatTimeRange(widget.initial)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ChoiceTile(
                    title: 'Change availability',
                    subtitle: 'Switch Full Day / Custom Hours or edit times',
                    icon: Icons.edit_calendar,
                    accent: AppColors.softPink,
                    onTap: () => Navigator.pop(context, 'change'),
                  ),
                  const SizedBox(height: 12),
                  _ChoiceTile(
                    title: 'Remove availability',
                    subtitle: 'This day will no longer be marked as available',
                    icon: Icons.delete_outline,
                    accent: AppColors.softYellow,
                    onTap: () => Navigator.pop(context, 'remove'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailabilityChoiceSheet extends StatefulWidget {
  final DateTime day;

  const _AvailabilityChoiceSheet({required this.day});

  @override
  State<_AvailabilityChoiceSheet> createState() =>
      _AvailabilityChoiceSheetState();
}

class _AvailabilityChoiceSheetState extends State<_AvailabilityChoiceSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            boxShadow: AppShadows.lg,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.md,
                AppSpacing.xxl,
                AppSpacing.xxl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'How are you available on ${_formatDayLabel(widget.day)}?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose how long you can work this day.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ChoiceTile(
                    title: 'Full Day',
                    subtitle: "I'm available all day · 07:00 → 18:00 (11h)",
                    icon: Icons.schedule,
                    accent: AppColors.softPink,
                    onTap: () =>
                        Navigator.pop(context, AvailabilityShiftType.fullTime),
                  ),
                  const SizedBox(height: 12),
                  _ChoiceTile(
                    title: 'Custom Hours',
                    subtitle: "Select the hours when you're available",
                    icon: Icons.tune,
                    accent: AppColors.softYellow,
                    onTap: () => Navigator.pop(
                      context,
                      AvailabilityShiftType.customHours,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Material(
        color: accent.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg + 2),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.pureWhite,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primaryPink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textDark.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomHoursSheet extends StatefulWidget {
  final DateTime day;
  final TimeOfDay? initialStart;
  final TimeOfDay? initialEnd;

  const _CustomHoursSheet({
    required this.day,
    this.initialStart,
    this.initialEnd,
  });

  @override
  State<_CustomHoursSheet> createState() => _CustomHoursSheetState();
}

class _CustomHoursSheetState extends State<_CustomHoursSheet>
    with SingleTickerProviderStateMixin {
  late TimeOfDay _start;
  late TimeOfDay _end;
  String? _error;
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart ?? const TimeOfDay(hour: 7, minute: 0);
    _end = widget.initialEnd ?? const TimeOfDay(hour: 18, minute: 0);
    _anim = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  bool _isWithinShopHours(TimeOfDay t) {
    final minutes = t.hour * 60 + t.minute;
    final open = SchedulingMonthUtils.shopOpenHour * 60;
    final close = SchedulingMonthUtils.shopCloseHour * 60;
    return minutes >= open && minutes <= close;
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) async {
    return showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primaryPink,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
      },
    );
  }

  void _confirm() {
    final startDt = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      _start.hour,
      _start.minute,
    );
    final endDt = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      _end.hour,
      _end.minute,
    );

    if (!_isWithinShopHours(_start) || !_isWithinShopHours(_end)) {
      setState(() => _error = 'Hours must be between 07:00 and 18:00.');
      return;
    }
    if (!endDt.isAfter(startDt)) {
      setState(() => _error = 'End time must be after start time.');
      return;
    }

    Navigator.pop(
      context,
      ShiftTypeSelectionResult(
        shiftType: AvailabilityShiftType.customHours,
        start: _start,
        end: _end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            boxShadow: AppShadows.lg,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.md,
                AppSpacing.xxl,
                AppSpacing.xxl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Custom hours — ${_formatDayLabel(widget.day)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Pick a start and end time (07:00–18:00).',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _TimePickerTile(
                          label: 'Start',
                          time: _start,
                          onTap: () async {
                            final t = await _pickTime(_start);
                            if (t != null) setState(() => _start = t);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimePickerTile(
                          label: 'End',
                          time: _end,
                          onTap: () async {
                            final t = await _pickTime(_end);
                            if (t != null) setState(() => _end = t);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePickerTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return InteractiveScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Material(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: AppSpacing.md,
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textDark.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                formatted,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryPink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Validates custom hours using the same rules as [_CustomHoursSheet].
bool validateCustomHoursSelection({
  required DateTime day,
  required TimeOfDay start,
  required TimeOfDay end,
}) {
  final startDt = DateTime(
    day.year,
    day.month,
    day.day,
    start.hour,
    start.minute,
  );
  final endDt = DateTime(day.year, day.month, day.day, end.hour, end.minute);

  final open = SchedulingMonthUtils.shopOpenHour * 60;
  final close = SchedulingMonthUtils.shopCloseHour * 60;
  final startMin = start.hour * 60 + start.minute;
  final endMin = end.hour * 60 + end.minute;

  if (startMin < open || endMin > close) return false;
  return endDt.isAfter(startDt);
}
