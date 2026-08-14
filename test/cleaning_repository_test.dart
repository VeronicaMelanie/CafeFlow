import 'package:fivetogo_scheduler/features/cleaning/data/cleaning_repository.dart';
import 'package:fivetogo_scheduler/features/cleaning/domain/cleaning_list_key.dart';
import 'package:fivetogo_scheduler/features/cleaning/domain/cleaning_task_model.dart';
import 'package:fivetogo_scheduler/features/cleaning/utils/cleaning_week_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CleaningRepository repository;

  setUp(() {
    repository = CleaningRepository.test();
  });

  test('Closing list id is shared and first in ordered keys', () {
    expect(CleaningListKey.ordered.first, CleaningListKey.closing);
    expect(
      CleaningListKey.listId('Gara', CleaningListKey.closing),
      'Gara_closing',
    );
    expect(
      CleaningListKey.listId('Gara', CleaningListKey.monday),
      isNot(CleaningListKey.listId('Gara', CleaningListKey.closing)),
    );
  });

  test('admin can create, edit, delete and reorder tasks', () async {
    final listId = CleaningListKey.listId('Gara', CleaningListKey.monday);
    final first = await repository.addTask(
      location: 'Gara',
      listKey: CleaningListKey.monday,
      title: 'Mop floor',
    );
    final second = await repository.addTask(
      location: 'Gara',
      listKey: CleaningListKey.monday,
      title: 'Clean tables',
    );

    var tasks = await repository.watchTasksForList(listId).first;
    expect(tasks.map((task) => task.title), ['Mop floor', 'Clean tables']);

    await repository.updateTaskTitle(first.id, 'Mop floor thoroughly');
    await repository.reorderTasks([second, first]);

    tasks = await repository.watchTasksForList(listId).first;
    expect(tasks.first.title, 'Clean tables');
    expect(tasks.last.title, 'Mop floor thoroughly');

    await repository.deleteTask(second.id);
    tasks = await repository.watchTasksForList(listId).first;
    expect(tasks, hasLength(1));
    expect(tasks.single.title, 'Mop floor thoroughly');
  });

  test('employee can check and uncheck tasks independently', () async {
    final task = await repository.addTask(
      location: 'Gara',
      listKey: CleaningListKey.closing,
      title: 'Take out trash',
    );
    const employeeA = 'employee-a';
    const employeeB = 'employee-b';
    const weekId = '2026-W33';

    await repository.setTaskCompletion(
      employeeId: employeeA,
      task: task,
      weekId: weekId,
      completed: true,
    );

    final aCompletions = await repository
        .watchCompletionsForEmployeeWeek(
          employeeId: employeeA,
          weekId: weekId,
          listId: task.listId,
        )
        .first;
    final bCompletions = await repository
        .watchCompletionsForEmployeeWeek(
          employeeId: employeeB,
          weekId: weekId,
          listId: task.listId,
        )
        .first;

    expect(aCompletions.single.completed, isTrue);
    expect(bCompletions, isEmpty);

    await repository.setTaskCompletion(
      employeeId: employeeA,
      task: task,
      weekId: weekId,
      completed: false,
    );
    final unchecked = await repository
        .watchCompletionsForEmployeeWeek(
          employeeId: employeeA,
          weekId: weekId,
          listId: task.listId,
        )
        .first;
    expect(unchecked.single.completed, isFalse);
  });

  test('completion stays in current week and resets for new week', () async {
    final task = await repository.addTask(
      location: 'Gara',
      listKey: CleaningListKey.tuesday,
      title: 'Wipe counters',
    );
    const employeeId = 'employee-a';
    const oldWeek = '2026-W32';
    const newWeek = '2026-W33';

    await repository.setTaskCompletion(
      employeeId: employeeId,
      task: task,
      weekId: oldWeek,
      completed: true,
    );

    final oldWeekCompletion = await repository
        .watchCompletionsForEmployeeWeek(
          employeeId: employeeId,
          weekId: oldWeek,
          listId: task.listId,
        )
        .first;
    final newWeekCompletion = await repository
        .watchCompletionsForEmployeeWeek(
          employeeId: employeeId,
          weekId: newWeek,
          listId: task.listId,
        )
        .first;

    expect(oldWeekCompletion.single.completed, isTrue);
    expect(newWeekCompletion, isEmpty);

    final tasks = await repository.watchTasksForList(task.listId).first;
    expect(tasks.single.title, 'Wipe counters');
  });

  test('locations do not mix task definitions', () async {
    await repository.addTask(
      location: 'Gara',
      listKey: CleaningListKey.friday,
      title: 'Gara task',
    );
    await repository.addTask(
      location: 'Avantgarden',
      listKey: CleaningListKey.friday,
      title: 'Avantgarden task',
    );

    final garaTasks = await repository
        .watchTasksForList(CleaningListKey.listId('Gara', CleaningListKey.friday))
        .first;
    final avantTasks = await repository
        .watchTasksForList(
          CleaningListKey.listId('Avantgarden', CleaningListKey.friday),
        )
        .first;

    expect(garaTasks.single.title, 'Gara task');
    expect(avantTasks.single.title, 'Avantgarden task');
  });

  test('buildEmployeeProgress distinguishes complete partial and not started', () {
    final tasks = [
      const CleaningTaskModel(
        id: '1',
        listId: 'Gara_closing',
        location: 'Gara',
        title: 'A',
        order: 0,
      ),
      const CleaningTaskModel(
        id: '2',
        listId: 'Gara_closing',
        location: 'Gara',
        title: 'B',
        order: 1,
      ),
    ];

    final notStarted = buildEmployeeProgress(
      employeeId: 'e1',
      employeeName: 'Veronica',
      tasks: tasks,
      completions: const [],
    );
    expect(notStarted.isNotStarted, isTrue);
    expect(notStarted.isPartial, isFalse);
    expect(notStarted.isComplete, isFalse);

    final partial = buildEmployeeProgress(
      employeeId: 'e1',
      employeeName: 'Gabriel',
      tasks: tasks,
      completions: [
        CleaningTaskCompletionModel(
          id: 'c1',
          employeeId: 'e1',
          taskId: '1',
          listId: 'Gara_closing',
          location: 'Gara',
          weekId: CleaningWeekUtils.weekIdFor(DateTime(2026, 8, 11)),
          completed: true,
        ),
      ],
    );
    expect(partial.isPartial, isTrue);
    expect(partial.completedCount, 1);

    final complete = buildEmployeeProgress(
      employeeId: 'e1',
      employeeName: 'Veronica',
      tasks: tasks,
      completions: [
        CleaningTaskCompletionModel(
          id: 'c1',
          employeeId: 'e1',
          taskId: '1',
          listId: 'Gara_closing',
          location: 'Gara',
          weekId: CleaningWeekUtils.weekIdFor(DateTime(2026, 8, 11)),
          completed: true,
        ),
        CleaningTaskCompletionModel(
          id: 'c2',
          employeeId: 'e1',
          taskId: '2',
          listId: 'Gara_closing',
          location: 'Gara',
          weekId: CleaningWeekUtils.weekIdFor(DateTime(2026, 8, 11)),
          completed: true,
        ),
      ],
    );
    expect(complete.isComplete, isTrue);
  });
}
