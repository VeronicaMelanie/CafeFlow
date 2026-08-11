import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/scheduling_service.dart';
import '../domain/availability_model.dart';
import '../domain/shift_type.dart';

/// Edit selected availability days: FULL (07–18) or CUSTOM hours.
class AvailabilityDaysEditorScreen extends ConsumerStatefulWidget {
  final Set<DateTime> selectedDays;

  const AvailabilityDaysEditorScreen({super.key, required this.selectedDays});

  @override
  ConsumerState<AvailabilityDaysEditorScreen> createState() =>
      _AvailabilityDaysEditorScreenState();
}

class _AvailabilityDaysEditorScreenState
    extends ConsumerState<AvailabilityDaysEditorScreen> {
  final Map<DateTime, _DayConfig> _configs = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final day in widget.selectedDays) {
      final normalized = DateTime(day.year, day.month, day.day);
      _configs[normalized] = _DayConfig(shiftType: AvailabilityShiftType.fullTime);
    }
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    for (final day in _configs.keys.toList()) {
      final snap = await FirebaseFirestore.instance
          .collection('availability')
          .where('userId', isEqualTo: user.uid)
          .where('date', isEqualTo: Timestamp.fromDate(day))
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final model = AvailabilityModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
        _configs[day] = _DayConfig(
          shiftType: model.shiftType,
          start: model.customStartTime != null
              ? TimeOfDay.fromDateTime(model.customStartTime!)
              : const TimeOfDay(hour: 7, minute: 0),
          end: model.customEndTime != null
              ? TimeOfDay.fromDateTime(model.customEndTime!)
              : const TimeOfDay(hour: 18, minute: 0),
          docId: snap.docs.first.id,
        );
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      for (final entry in _configs.entries) {
        final day = entry.key;
        final config = entry.value;

        DateTime? customStart;
        DateTime? customEnd;
        if (config.shiftType == AvailabilityShiftType.customHours) {
          customStart = DateTime(
            day.year, day.month, day.day,
            config.start.hour, config.start.minute,
          );
          customEnd = DateTime(
            day.year, day.month, day.day,
            config.end.hour, config.end.minute,
          );
          if (!customEnd.isAfter(customStart)) {
            throw Exception('Invalid hours on ${DateFormat.MMMd().format(day)}');
          }
        }

        final model = AvailabilityModel(
          id: config.docId ?? '',
          userId: user.uid,
          date: day,
          shiftType: config.shiftType,
          customStartTime: customStart,
          customEndTime: customEnd,
        );

        if (config.docId != null) {
          await FirebaseFirestore.instance
              .collection('availability')
              .doc(config.docId)
              .set(model.toMap());
        } else {
          await FirebaseFirestore.instance
              .collection('availability')
              .add(model.toMap());
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Availability saved')),
        );
        Navigator.pop(context, true);
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
    final user = ref.watch(currentUserProvider).value;
    final location = user?.primaryLocation ?? 'Gara';

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Column(
        children: [
          ScreenHeader(
            title: 'Edit availability',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Text(
                  'Configure each day. Full Time = 07:00–18:00 (11h).',
                  style: TextStyle(
                    color: AppColors.textDark.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ..._configs.entries.map((e) => _buildDayTile(e.key, e.value, location)),
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  text: 'Save availability',
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTile(DateTime day, _DayConfig config, String location) {
    return AppSurface(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEE, MMM d').format(day),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                _CapacityChip(date: day, location: location),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<AvailabilityShiftType>(
              segments: [
                ButtonSegment(
                  value: AvailabilityShiftType.fullTime,
                  label: Text(AvailabilityShiftType.fullTime.displayLabel),
                ),
                ButtonSegment(
                  value: AvailabilityShiftType.customHours,
                  label: Text(AvailabilityShiftType.customHours.displayLabel),
                ),
              ],
              selected: {config.shiftType},
              onSelectionChanged: (s) =>
                  setState(() => config.shiftType = s.first),
            ),
            if (config.shiftType == AvailabilityShiftType.customHours) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: config.start,
                        );
                        if (t != null) setState(() => config.start = t);
                      },
                      child: Text('Start ${config.start.format(context)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: config.end,
                        );
                        if (t != null) setState(() => config.end = t);
                      },
                      child: Text('End ${config.end.format(context)}'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
    );
  }
}

class _DayConfig {
  AvailabilityShiftType shiftType;
  TimeOfDay start;
  TimeOfDay end;
  String? docId;

  _DayConfig({
    required this.shiftType,
    this.start = const TimeOfDay(hour: 7, minute: 0),
    this.end = const TimeOfDay(hour: 18, minute: 0),
    this.docId,
  });
}

class _CapacityChip extends StatelessWidget {
  final DateTime date;
  final String location;

  const _CapacityChip({required this.date, required this.location});

  @override
  Widget build(BuildContext context) {
    final scheduling = SchedulingService();
    return StreamBuilder<Map<String, dynamic>>(
      stream: scheduling.watchCapacityInfo(date, location),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        final data = snapshot.data!;
        final remaining = data['remainingHours'] as double;
        Color color;
        String label;
        if (data['isFull'] == true) {
          color = Colors.red.shade100;
          label = 'Full';
        } else if (data['isAlmostFull'] == true) {
          color = Colors.amber.shade100;
          label = '${remaining.toStringAsFixed(0)}h left';
        } else {
          color = Colors.green.shade100;
          label = '${remaining.toStringAsFixed(0)}h left';
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        );
      },
    );
  }
}
