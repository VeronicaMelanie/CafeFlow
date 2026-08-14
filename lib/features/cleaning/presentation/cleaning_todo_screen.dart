import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../scheduling/presentation/scheduling_providers.dart';
import '../data/cleaning_notification_helper.dart';
import '../domain/cleaning_list_key.dart';
import '../domain/cleaning_task_model.dart';
import '../utils/cleaning_location_utils.dart';
import 'cleaning_providers.dart';
import 'cleaning_todo_content.dart';

class CleaningTodoScreen extends ConsumerStatefulWidget {
  const CleaningTodoScreen({super.key});

  @override
  ConsumerState<CleaningTodoScreen> createState() =>
      _CleaningTodoScreenState();
}

class _CleaningTodoScreenState extends ConsumerState<CleaningTodoScreen> {
  CleaningListKey _selectedListKey = CleaningListKey.closing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSelectedLocation());
  }

  void _syncSelectedLocation() {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final selected = ref.read(selectedLocationProvider);
    final effective = effectiveLocationForEmployee(user, selected);
    if (effective != selected) {
      ref.read(selectedLocationProvider.notifier).state = effective;
    }
  }

  Future<void> _toggleTask(CleaningTaskModel task) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final repository = ref.read(cleaningRepositoryProvider);
    final weekId = ref.read(cleaningWeekIdProvider);
    final location = effectiveLocationForEmployee(
      user,
      ref.read(selectedLocationProvider),
    );
    final query = cleaningQueryForEmployee(
      ref,
      listKey: _selectedListKey,
      employeeId: user.uid,
      location: location,
    );
    final views = ref.read(cleaningTaskViewsProvider(query)).value ?? [];
    final current = views.firstWhere(
      (view) => view.task.id == task.id,
      orElse: () => CleaningTaskViewModel(task: task, completed: false),
    );
    final nextCompleted = !current.completed;

    await repository.setTaskCompletion(
      employeeId: user.uid,
      task: task,
      weekId: weekId,
      completed: nextCompleted,
    );

    if (!nextCompleted) return;

    final updatedViews = views
        .map(
          (view) => view.task.id == task.id
              ? CleaningTaskViewModel(task: view.task, completed: true)
              : view,
        )
        .toList();
    final allDone = updatedViews.isNotEmpty &&
        updatedViews.every((view) => view.completed);
    if (allDone) {
      await CleaningNotificationHelper.notifyAdminAllTasksCompleted(
        employeeName: user.name,
        listKey: _selectedListKey,
        employeeId: user.uid,
        weekId: weekId,
        location: location,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not logged in'));
          }
          return _buildForUser(user);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildForUser(UserModel user) {
    final selectedLocation = ref.watch(selectedLocationProvider);
    final location = effectiveLocationForEmployee(user, selectedLocation);

    final query = cleaningQueryForEmployee(
      ref,
      listKey: _selectedListKey,
      employeeId: user.uid,
      location: location,
    );
    final taskViewsAsync = ref.watch(cleaningTaskViewsProvider(query));

    return taskViewsAsync.when(
      loading: () => CleaningTodoContent(
        selectedListKey: _selectedListKey,
        onListKeyChanged: (key) => setState(() => _selectedListKey = key),
        taskViews: const [],
        isLoading: true,
        onToggleTask: _toggleTask,
        locationLabel: location,
      ),
      error: (error, _) => CleaningTodoContent(
        selectedListKey: _selectedListKey,
        onListKeyChanged: (key) => setState(() => _selectedListKey = key),
        taskViews: const [],
        onToggleTask: (_) {},
        locationLabel: location,
        errorMessage: _humanizeCleaningError(error),
      ),
      data: (taskViews) => CleaningTodoContent(
        selectedListKey: _selectedListKey,
        onListKeyChanged: (key) => setState(() => _selectedListKey = key),
        taskViews: taskViews,
        onToggleTask: _toggleTask,
        locationLabel: location,
      ),
    );
  }

  String _humanizeCleaningError(Object error) {
    final message = error.toString();
    if (message.contains('permission-denied')) {
      return 'Could not load cleaning tasks. Please check your connection and try again.';
    }
    return 'Could not load cleaning tasks. $message';
  }
}
