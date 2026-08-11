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
import '../../scheduling/domain/shift_model.dart';

class ManageScheduleScreen extends ConsumerStatefulWidget {
  const ManageScheduleScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ManageScheduleScreen> createState() => _ManageScheduleScreenState();
}

class _ManageScheduleScreenState extends ConsumerState<ManageScheduleScreen> {
  final SchedulingService _schedulingService = SchedulingService();
  List<ShiftModel> _draftShifts = [];
  bool _isGenerating = false;
  DateTime _selectedMonth = DateTime.now().add(const Duration(days: 15));

  Future<void> _generateDraft() async {
    setState(() => _isGenerating = true);
    try {
      final shifts = await _schedulingService.generateDraftSchedule(_selectedMonth);
      setState(() {
        _draftShifts = shifts;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _publish() async {
    if (_draftShifts.isEmpty) return;
    
    setState(() => _isGenerating = true);
    try {
      await _schedulingService.publishSchedule(_draftShifts);
      setState(() {
        _draftShifts = [];
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule Published Successfully! 📅'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.softGreen,
        ),
      );
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            ScreenHeader(
              title: 'Schedule Manager',
              onBack: () => Navigator.pop(context),
            ),
            _buildControlBar(),
            Expanded(
              child: _isGenerating
                  ? const AppLoadingIndicator()
                  : _draftShifts.isEmpty
                      ? _buildEmptyState()
                      : _buildShiftsList(),
            ),
            if (_draftShifts.isNotEmpty && !_isGenerating) _buildPublishButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.xl),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.6), width: 0.5),
        boxShadow: AppShadows.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selected Month', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              Text(DateFormat('MMMM yyyy').format(_selectedMonth), 
                   style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primaryPink)),
            ],
          ),
          ElevatedButton(
            onPressed: _isGenerating ? null : _generateDraft,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.softPink,
              foregroundColor: AppColors.primaryPink,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
            ),
            child: const Text('Generate Draft'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: AppColors.textLight.withValues(alpha: 0.3)),
          const SizedBox(height: AppSpacing.lg),
          const Text('No draft generated yet', style: TextStyle(color: AppColors.textLight, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Press "Generate Draft" to start', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildShiftsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      itemCount: _draftShifts.length,
      itemBuilder: (context, index) {
        final shift = _draftShifts[index];
        final isGara = shift.location == 'Gara';
        
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.6), width: 0.5),
            boxShadow: AppShadows.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: (isGara ? AppColors.softGreen : AppColors.softYellow).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Center(
                  child: Text(shift.location[0], 
                  style: TextStyle(fontWeight: FontWeight.bold, color: isGara ? Colors.green : Colors.orange)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shift.userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(
                      '${DateFormat('EEE, MMM dd').format(shift.date)} | ${DateFormat('HH:mm').format(shift.startTime)} - ${DateFormat('HH:mm').format(shift.endTime)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.softBlue, borderRadius: BorderRadius.circular(8)),
                child: Text('${shift.durationInHours}h', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPublishButton() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        boxShadow: AppShadows.lg,
      ),
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.green, Color(0xFF4CAF50)]),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          boxShadow: AppShadows.coloredGlow(Colors.green),
        ),
        child: ElevatedButton(
          onPressed: _publish,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
          ),
          child: const Text('Approve & Publish', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
