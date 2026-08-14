import 'package:fivetogo_scheduler/features/cleaning/domain/cleaning_list_key.dart';
import 'package:fivetogo_scheduler/features/cleaning/domain/cleaning_task_model.dart';
import 'package:fivetogo_scheduler/features/cleaning/presentation/cleaning_todo_content.dart';
import 'package:fivetogo_scheduler/features/cleaning/presentation/widgets/cleaning_day_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CleaningTaskViewModel _view(String id, String title, {bool completed = false}) {
  return CleaningTaskViewModel(
    task: CleaningTaskModel(
      id: id,
      listId: 'Gara_closing',
      location: 'Gara',
      title: title,
      order: 0,
    ),
    completed: completed,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('Closing is first in day selector', (tester) async {
    CleaningListKey selected = CleaningListKey.closing;

    await tester.pumpWidget(
      _wrap(
        CleaningDaySelector(
          selectedKey: selected,
          onChanged: (key) => selected = key,
        ),
      ),
    );

    expect(find.text('Closing'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
  });

  testWidgets('horizontal day selection changes selected list key', (tester) async {
    var selected = CleaningListKey.closing;

    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return CleaningTodoContent(
              selectedListKey: selected,
              onListKeyChanged: (key) => setState(() => selected = key),
              taskViews: [_view('1', 'Empty coffee grounds')],
              onToggleTask: (_) {},
            );
          },
        ),
      ),
    );

    expect(find.text('Empty coffee grounds'), findsOneWidget);
    await tester.tap(find.text('Tue'));
    await tester.pumpAndSettle();
    expect(selected, CleaningListKey.tuesday);
  });

  testWidgets('employee can check and uncheck tasks and progress updates',
      (tester) async {
    final views = <CleaningTaskViewModel>[
      _view('1', 'Clean espresso machine'),
      _view('2', 'Wipe counters'),
    ];

    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return CleaningTodoContent(
              selectedListKey: CleaningListKey.closing,
              onListKeyChanged: (_) {},
              taskViews: views,
              onToggleTask: (task) {
                setState(() {
                  final index = views.indexWhere((v) => v.task.id == task.id);
                  final current = views[index];
                  views[index] = CleaningTaskViewModel(
                    task: current.task,
                    completed: !current.completed,
                  );
                });
              },
            );
          },
        ),
      ),
    );

    expect(find.text('0 / 2 completed'), findsOneWidget);

    await tester.tap(find.text('Clean espresso machine'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 completed'), findsOneWidget);

    await tester.tap(find.text('Clean espresso machine'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 2 completed'), findsOneWidget);
  });

  testWidgets('all-completed state appears', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CleaningTodoContent(
          selectedListKey: CleaningListKey.closing,
          onListKeyChanged: (_) {},
          taskViews: [
            _view('1', 'Empty coffee grounds', completed: true),
            _view('2', 'Mop the floor', completed: true),
          ],
          onToggleTask: (_) {},
        ),
      ),
    );

    expect(find.text('2 / 2 completed'), findsOneWidget);
    expect(find.text('All checks are marked!'), findsOneWidget);
  });

  testWidgets('employee cannot edit task definitions from checklist UI',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        CleaningTodoContent(
          selectedListKey: CleaningListKey.closing,
          onListKeyChanged: (_) {},
          taskViews: [_view('1', 'Clean display case')],
          onToggleTask: (_) {},
          canEditTasks: false,
        ),
      ),
    );

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('failed query shows error state instead of empty tasks',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        CleaningTodoContent(
          selectedListKey: CleaningListKey.closing,
          onListKeyChanged: (_) {},
          taskViews: const [],
          onToggleTask: (_) {},
          errorMessage: 'Could not load cleaning tasks.',
        ),
      ),
    );

    expect(find.text('Could not load cleaning tasks.'), findsOneWidget);
    expect(find.textContaining('No tasks configured'), findsNothing);
  });
}
