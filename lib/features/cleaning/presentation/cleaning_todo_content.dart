import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/screen_header.dart';
import '../domain/cleaning_list_key.dart';
import '../domain/cleaning_task_model.dart';
import 'widgets/cleaning_day_selector.dart';

class CleaningTodoContent extends StatelessWidget {
  final CleaningListKey selectedListKey;
  final ValueChanged<CleaningListKey> onListKeyChanged;
  final List<CleaningTaskViewModel> taskViews;
  final ValueChanged<CleaningTaskModel> onToggleTask;
  final bool isLoading;
  final bool canEditTasks;
  final String? errorMessage;
  final String? infoMessage;
  final String? locationLabel;

  const CleaningTodoContent({
    super.key,
    required this.selectedListKey,
    required this.onListKeyChanged,
    required this.taskViews,
    required this.onToggleTask,
    this.isLoading = false,
    this.canEditTasks = false,
    this.errorMessage,
    this.infoMessage,
    this.locationLabel,
  });

  int get _completedCount =>
      taskViews.where((view) => view.completed).length;

  double get _progress =>
      taskViews.isEmpty ? 0 : _completedCount / taskViews.length;

  bool get _allCompleted =>
      taskViews.isNotEmpty && _completedCount == taskViews.length;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScreenHeader(
          title: 'Cleaning To-Do List',
          onBack: () => Navigator.pop(context),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CleaningDaySelector(
                  selectedKey: selectedListKey,
                  onChanged: onListKeyChanged,
                ),
                if (locationLabel != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Location: $locationLabel',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandTurquoise,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                if (errorMessage != null)
                  _ErrorTasksState(message: errorMessage!)
                else if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (taskViews.isEmpty)
                  _EmptyTasksState(listLabel: selectedListKey.label)
                else ...[
                  AppSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedListKey.label,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '$_completedCount / ${taskViews.length} completed',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandTurquoise,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusPill),
                          child: LinearProgressIndicator(
                            value: _progress,
                            minHeight: 10,
                            backgroundColor: AppColors.borderLight,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.brandGreen,
                            ),
                          ),
                        ),
                        if (_allCompleted) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.brandGreen.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.brandGreen,
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'All checks are marked!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.brandGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ...taskViews.map(
                    (view) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _CleaningTaskTile(
                        view: view,
                        onChanged: canEditTasks
                            ? null
                            : (value) => onToggleTask(view.task),
                      ),
                    ),
                  ),
                ],
                if (infoMessage != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _InfoBanner(message: infoMessage!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;

  const _InfoBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      color: AppColors.brandTurquoise.withValues(alpha: 0.08),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.brandTurquoise,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorTasksState extends StatelessWidget {
  final String message;

  const _ErrorTasksState({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      color: AppColors.brandRed.withValues(alpha: 0.06),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.brandRed.withValues(alpha: 0.8),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.brandRed,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CleaningTaskTile extends StatelessWidget {
  final CleaningTaskViewModel view;
  final ValueChanged<bool>? onChanged;

  const _CleaningTaskTile({
    required this.view,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final completed = view.completed;
    return AppSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!completed),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Checkbox(
                value: completed,
                onChanged: onChanged == null
                    ? null
                    : (value) => onChanged!(value ?? false),
                activeColor: AppColors.brandGreen,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  view.task.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: completed
                        ? AppColors.textLight
                        : AppColors.textDark,
                    decoration:
                        completed ? TextDecoration.lineThrough : null,
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

class _EmptyTasksState extends StatelessWidget {
  final String listLabel;

  const _EmptyTasksState({required this.listLabel});

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Column(
        children: [
          Icon(
            Icons.cleaning_services_outlined,
            size: 48,
            color: AppColors.textLight.withValues(alpha: 0.35),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No tasks configured for $listLabel yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
