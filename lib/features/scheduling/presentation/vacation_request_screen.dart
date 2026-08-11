import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/vacation_repository.dart';
import '../domain/vacation_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/screen_header.dart';

class VacationRequestScreen extends ConsumerStatefulWidget {
  const VacationRequestScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<VacationRequestScreen> createState() =>
      _VacationRequestScreenState();
}

class _VacationRequestScreenState extends ConsumerState<VacationRequestScreen> {
  DateTime _startDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    1,
  );
  DateTime _endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    3,
  );
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final vacation = VacationModel(
        id: '',
        userId: user.uid,
        userName: user.name,
        startDate: _startDate,
        endDate: _endDate,
        status: 'pending',
        requestedAt: DateTime.now(),
      );

      await ref.read(vacationRepositoryProvider).requestVacation(vacation);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vacation request submitted successfully!'),
            backgroundColor: AppColors.softGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = _endDate.difference(_startDate).inDays + 1;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Column(
        children: [
          ScreenHeader(
            title: 'Request Vacation',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateSelector(textTheme),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildDurationCard(duration, textTheme),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildCommentField(),
                  const SizedBox(height: AppSpacing.xxxl),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(TextTheme textTheme) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Dates',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.lg),
          TableCalendar(
            firstDay: DateTime(
              DateTime.now().year,
              DateTime.now().month + 1,
              1,
            ),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _startDate,
            rangeStartDay: _startDate,
            rangeEndDay: _endDate,
            calendarFormat: CalendarFormat.month,
            rangeSelectionMode: RangeSelectionMode.enforced,
            onRangeSelected: (start, end, focusedDay) {
              setState(() {
                _startDate = start ?? _startDate;
                _endDate = end ?? start ?? _endDate;
              });
            },
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w800),
              leftChevronIcon: const Icon(
                Icons.chevron_left,
                color: AppColors.primaryPink,
              ),
              rightChevronIcon: const Icon(
                Icons.chevron_right,
                color: AppColors.primaryPink,
              ),
            ),
            calendarStyle: CalendarStyle(
              rangeHighlightColor: AppColors.primaryPink.withValues(alpha: 0.2),
              withinRangeTextStyle: const TextStyle(
                color: AppColors.primaryPink,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppColors.primaryPink,
                shape: BoxShape.circle,
              ),
              todayDecoration: const BoxDecoration(
                color: AppColors.accentPink,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationCard(int duration, TextTheme textTheme) {
    return AppSurface(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.softBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_today,
              color: AppColors.primaryPink,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duration',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textLight),
                ),
                Text(
                  '$duration day${duration > 1 ? 's' : ''}',
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text(
              '${duration * 11}h',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentField() {
    return AppSurface(
      margin: EdgeInsets.zero,
      child: TextField(
        controller: _commentController,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Comments (optional)',
          hintText: 'Add any notes for the admin...',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                  strokeCap: StrokeCap.round,
                ),
              )
            : const Text(
                'Submit Request',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }
}
