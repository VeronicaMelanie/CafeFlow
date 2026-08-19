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
import '../../locations/presentation/location_providers.dart';
import '../../scheduling/data/scheduling_service.dart';
import '../../scheduling/presentation/scheduling_providers.dart';

/// Admin view: daily occupancy, underbooked and fully occupied days per location.
class StaffingOverviewScreen extends ConsumerStatefulWidget {
  const StaffingOverviewScreen({super.key});

  @override
  ConsumerState<StaffingOverviewScreen> createState() =>
      _StaffingOverviewScreenState();
}

class _StaffingOverviewScreenState extends ConsumerState<StaffingOverviewScreen> {
  String _location = 'Gara';
  DateTime _month = DateTime.now();
  bool _loading = true;
  List<DateTime> _underbooked = [];
  List<DateTime> _full = [];
  Map<int, double> _dailyHours = {};

  SchedulingService get _scheduling => ref.read(schedulingServiceProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final under = await _scheduling.getUnderbookedDays(_month, _location);
    final full = await _scheduling.getFullyOccupiedDays(_month, _location);
    final end = DateTime(_month.year, _month.month + 1, 0);
    final hours = <int, double>{};
    for (int d = 1; d <= end.day; d++) {
      final date = DateTime(_month.year, _month.month, d);
      final cap = await _scheduling.getCapacityInfo(date, _location);
      hours[d] = cap['totalHours'] as double;
    }
    setState(() {
      _underbooked = under;
      _full = full;
      _dailyHours = hours;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            ScreenHeader(
              title: l10n.pick('Staffing overview', 'Situație personal'),
              onBack: () => Navigator.pop(context),
            ),
            _buildControls(),
            Expanded(
              child: _loading
                  ? const AppLoadingIndicator()
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      children: [
                        _buildSummaryCards(),
                        const SizedBox(height: AppSpacing.xxl),
                        _buildSection(
                          l10n.pick(
                            'Understaffed days (< 18h)',
                            'Zile sub-acoperite (< 18h)',
                          ),
                          _underbooked,
                          AppColors.softYellow,
                          Icons.trending_down,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _buildSection(
                          l10n.pick(
                            'Fully occupied (22h)',
                            'Complet ocupate (22h)',
                          ),
                          _full,
                          AppColors.softPink,
                          Icons.block,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          l10n.pick('Daily occupancy', 'Ocupare zilnică'),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ..._dailyHours.entries.map((e) => _buildDayBar(e.key, e.value)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    final names = watchLocationNames(ref);
    final selected = names.contains(_location)
        ? _location
        : (names.isNotEmpty ? names.first : _location);
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: names.isEmpty
                ? const SizedBox.shrink()
                : SegmentedButton<String>(
                    segments: [
                      for (final name in names)
                        ButtonSegment(value: name, label: Text(name)),
                    ],
                    selected: {selected},
                    onSelectionChanged: (s) {
                      setState(() => _location = s.first);
                      _load();
                    },
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() => _month = DateTime(_month.year, _month.month - 1));
              _load();
            },
          ),
          Text(
            DateFormat('MMM yyyy', l10n.isRo ? null : l10n.locale.languageCode).format(_month),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() => _month = DateTime(_month.year, _month.month + 1));
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final l10n = L10n.of(context);
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            '${_underbooked.length}',
            l10n.pick('Understaffed', 'Sub-acoperite'),
            AppColors.softYellow,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _summaryCard(
            '${_full.length}',
            l10n.pick('Fully occupied', 'Complet ocupate'),
            AppColors.softPink,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<DateTime> days,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.6), width: 0.5),
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryPink, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          if (days.isEmpty)
            Text(
              L10n.of(context).pick(
                'None this month',
                'Niciuna luna asta',
              ),
              style: const TextStyle(color: AppColors.textLight),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: days.map((d) {
                return Chip(
                  label: Text(
                    DateFormat('MMM d', L10n.of(context).isRo ? null : L10n.of(context).locale.languageCode)
                        .format(d),
                  ),
                  backgroundColor: color.withValues(alpha: 0.4),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDayBar(int day, double hours) {
    final progress = (hours / 22).clamp(0.0, 1.0);
    Color barColor = AppColors.softGreen;
    if (hours >= 22) barColor = Colors.red.shade300;
    else if (hours >= 18) barColor = AppColors.softYellow;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('$day', style: const TextStyle(fontSize: 12))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.borderLight,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '${hours.toStringAsFixed(0)}h',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
