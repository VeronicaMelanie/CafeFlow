import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/widgets/admin_guard.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';
import '../../scheduling/data/scheduling_service.dart';

/// Admin view: daily occupancy, underbooked and fully occupied days per location.
class StaffingOverviewScreen extends ConsumerStatefulWidget {
  const StaffingOverviewScreen({super.key});

  @override
  ConsumerState<StaffingOverviewScreen> createState() =>
      _StaffingOverviewScreenState();
}

class _StaffingOverviewScreenState extends ConsumerState<StaffingOverviewScreen> {
  final SchedulingService _scheduling = SchedulingService();
  String _location = 'Gara';
  DateTime _month = DateTime.now();
  bool _loading = true;
  List<DateTime> _underbooked = [];
  List<DateTime> _full = [];
  Map<int, double> _dailyHours = {};

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
    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            ScreenHeader(
              title: 'Staffing Overview',
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
                          'Underbooked days (< 18h)',
                          _underbooked,
                          AppColors.softYellow,
                          Icons.trending_down,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _buildSection(
                          'Fully occupied (22h)',
                          _full,
                          AppColors.softPink,
                          Icons.block,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          'Daily occupancy',
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Gara', label: Text('Gara')),
                ButtonSegment(value: 'Avantgarden', label: Text('Avantgarden')),
              ],
              selected: {_location},
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
          Text(DateFormat('MMM yyyy').format(_month)),
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
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            '${_underbooked.length}',
            'Underbooked',
            AppColors.softYellow,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _summaryCard(
            '${_full.length}',
            'Fully booked',
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
            const Text('None this month', style: TextStyle(color: AppColors.textLight))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: days.map((d) {
                return Chip(
                  label: Text(DateFormat('MMM d').format(d)),
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
