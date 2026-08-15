import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/admin_guard.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../locations/presentation/location_providers.dart';
import '../data/cleaning_repository.dart';
import '../domain/cleaning_list_key.dart';
import '../domain/cleaning_task_model.dart';
import 'cleaning_providers.dart';
import 'widgets/cleaning_day_selector.dart';

class CleaningListsAdminScreen extends ConsumerStatefulWidget {
  const CleaningListsAdminScreen({super.key});

  @override
  ConsumerState<CleaningListsAdminScreen> createState() =>
      _CleaningListsAdminScreenState();
}

class _CleaningListsAdminScreenState
    extends ConsumerState<CleaningListsAdminScreen>
    with SingleTickerProviderStateMixin {
  CleaningListKey _selectedListKey = CleaningListKey.closing;
  String _selectedLocation = 'Gara';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add cleaning task'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Task name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (title == null || title.trim().isEmpty) return;

    final listId = CleaningListKey.listId(_selectedLocation, _selectedListKey);
    try {
      await ref.read(cleaningRepositoryProvider).addTask(
            location: _selectedLocation,
            listKey: _selectedListKey,
            title: title,
          );
      ref.invalidate(cleaningTasksForListProvider(listId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _editTask(CleaningTaskModel task) async {
    final controller = TextEditingController(text: task.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit cleaning task'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Task name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (title == null || title.trim().isEmpty) return;
    try {
      await ref
          .read(cleaningRepositoryProvider)
          .updateTaskTitle(task.id, title.trim());
      ref.invalidate(cleaningTasksForListProvider(task.listId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _deleteTask(CleaningTaskModel task) async {
    try {
      await ref.read(cleaningRepositoryProvider).deleteTask(task.id);
      ref.invalidate(cleaningTasksForListProvider(task.listId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
      );
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
              title: 'Cleaning To-Do Lists',
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LocationSelector(
                    selectedLocation: _selectedLocation,
                    onChanged: (location) =>
                        setState(() => _selectedLocation = location),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CleaningDaySelector(
                    selectedKey: _selectedListKey,
                    onChanged: (key) => setState(() => _selectedListKey = key),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.brandGreen,
                    unselectedLabelColor: AppColors.textLight,
                    indicatorColor: AppColors.brandGreen,
                    tabs: const [
                      Tab(text: 'Manage Tasks'),
                      Tab(text: 'Completion'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ManageTasksTab(
                    listId: CleaningListKey.listId(
                      _selectedLocation,
                      _selectedListKey,
                    ),
                    onAddTask: _addTask,
                    onEditTask: _editTask,
                    onDeleteTask: _deleteTask,
                  ),
                  _CompletionTab(
                    location: _selectedLocation,
                    listKey: _selectedListKey,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationSelector extends ConsumerWidget {
  final String selectedLocation;
  final ValueChanged<String> onChanged;

  const _LocationSelector({
    required this.selectedLocation,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = watchLocationNames(ref);
    if (locations.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      children: locations.map((location) {
        final selected = location == selectedLocation;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: location == locations.first ? AppSpacing.sm : 0,
            ),
            child: OutlinedButton(
              onPressed: () => onChanged(location),
              style: OutlinedButton.styleFrom(
                backgroundColor: selected
                    ? AppColors.brandTurquoise.withValues(alpha: 0.15)
                    : AppColors.pureWhite,
                foregroundColor: selected
                    ? AppColors.brandTurquoise
                    : AppColors.textLight,
              ),
              child: Text(location),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ManageTasksTab extends ConsumerWidget {
  final String listId;
  final VoidCallback onAddTask;
  final ValueChanged<CleaningTaskModel> onEditTask;
  final ValueChanged<CleaningTaskModel> onDeleteTask;

  const _ManageTasksTab({
    required this.listId,
    required this.onAddTask,
    required this.onEditTask,
    required this.onDeleteTask,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(cleaningTasksForListProvider(listId));

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (tasks) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: AppButton(
                text: '+ Add Item',
                onPressed: onAddTask,
                backgroundColor: AppColors.brandGreen,
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? const Center(
                      child: Text(
                        'No tasks yet. Add the first cleaning task.',
                        style: TextStyle(color: AppColors.textLight),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      itemCount: tasks.length,
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final reordered = List<CleaningTaskModel>.from(tasks);
                        final item = reordered.removeAt(oldIndex);
                        reordered.insert(newIndex, item);
                        try {
                          await ref
                              .read(cleaningRepositoryProvider)
                              .reorderTasks(reordered);
                          ref.invalidate(cleaningTasksForListProvider(listId));
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return AppSurface(
                          key: ValueKey(task.id),
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: [
                              const Icon(Icons.drag_handle_rounded,
                                  color: AppColors.textLight),
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => onEditTask(task),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => onDeleteTask(task),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _CompletionTab extends ConsumerWidget {
  final String location;
  final CleaningListKey listKey;

  const _CompletionTab({
    required this.location,
    required this.listKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listId = CleaningListKey.listId(location, listKey);
    final weekId = ref.watch(cleaningWeekIdProvider);
    final tasksAsync = ref.watch(cleaningTasksForListProvider(listId));
    final completionsAsync = ref.watch(
      cleaningAdminCompletionsProvider(
        CleaningListQuery(
          listId: listId,
          location: location,
          employeeId: '',
          weekId: weekId,
        ),
      ),
    );
    final employeesAsync = ref.watch(allEmployeesProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (tasks) {
        return employeesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (employees) {
            return completionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
              data: (completions) {
                final locationEmployees = employees
                    .where(
                      (employee) =>
                          employee.primaryLocation == location ||
                          employee.secondaryLocation == location,
                    )
                    .toList();

                if (locationEmployees.isEmpty) {
                  return const Center(
                    child: Text('No employees for this location.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  itemCount: locationEmployees.length,
                  itemBuilder: (context, index) {
                    final employee = locationEmployees[index];
                    final employeeCompletions = completions
                        .where(
                          (item) => item.employeeId == employee.uid,
                        )
                        .toList();
                    final progress = buildEmployeeProgress(
                      employeeId: employee.uid,
                      employeeName: employee.name,
                      tasks: tasks,
                      completions: employeeCompletions,
                    );

                    return AppSurface(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  employee.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  listKey.label,
                                  style: const TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${progress.completedCount} / ${progress.totalCount} completed',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: progress.isComplete
                                  ? AppColors.brandGreen
                                  : progress.isPartial
                                      ? AppColors.brandMustard
                                      : AppColors.textLight,
                            ),
                          ),
                          if (progress.isComplete) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.brandGreen,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
