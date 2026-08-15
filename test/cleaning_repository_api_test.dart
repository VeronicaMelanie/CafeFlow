import 'dart:io';

import 'package:fivetogo_scheduler/core/api/api_exception.dart';
import 'package:fivetogo_scheduler/features/auth/data/users_repository.dart';
import 'package:fivetogo_scheduler/features/cleaning/data/cleaning_repository.dart';
import 'package:fivetogo_scheduler/features/cleaning/domain/cleaning_list_key.dart';
import 'package:fivetogo_scheduler/features/cleaning/domain/cleaning_task_model.dart';
import 'package:fivetogo_scheduler/features/locations/data/location_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/api_test_harness.dart';
import 'helpers/vcc_api_fixtures.dart';

void main() {
  test('maps lists to Gara_closing identity, not UUID, and filters tasks',
      () async {
    final paths = <String>[];
    final repos = buildVccRepos(vccApiMock(capturedPaths: paths));
    final garaClosing = CleaningListKey.listId('Gara', CleaningListKey.closing);

    final tasks = await repos.cleaning.watchTasksForList(garaClosing).first;
    expect(paths, contains('/api/cleaning'));
    expect(tasks.map((t) => t.title), ['Spalare LAF', 'mop']);
    expect(tasks.every((t) => t.listId == garaClosing), isTrue);
    expect(tasks.every((t) => t.location == 'Gara'), isTrue);
    expect(tasks.every((t) => t.listId != 'list-gara-closing'), isTrue);
    expect(tasks.any((t) => t.id == 'task-inactive'), isFalse);
    expect(tasks.first.order, 0);
  });

  test('maps completions with Firebase UID and location/list filters', () async {
    final repos = buildVccRepos(vccApiMock());
    final garaClosing = CleaningListKey.listId('Gara', CleaningListKey.closing);
    final agClosing =
        CleaningListKey.listId('Avantgarden', CleaningListKey.closing);

    final employeeWeek = await repos.cleaning
        .watchCompletionsForEmployeeWeek(
          employeeId: 'firebase-employee-1',
          weekId: '2026-W32',
          listId: garaClosing,
        )
        .first;
    expect(employeeWeek, hasLength(2));
    expect(
      employeeWeek.every((c) => c.employeeId == 'firebase-employee-1'),
      isTrue,
    );
    expect(employeeWeek.every((c) => c.location == 'Gara'), isTrue);
    expect(employeeWeek.every((c) => c.listId == garaClosing), isTrue);
    expect(employeeWeek.any((c) => c.id == 'comp-unknown-user'), isFalse);
    expect(
      employeeWeek.firstWhere((c) => c.id == 'comp-1').completed,
      isTrue,
    );
    expect(
      employeeWeek.firstWhere((c) => c.id == 'comp-2').completed,
      isFalse,
    );

    final otherWeek = await repos.cleaning
        .watchCompletionsForEmployeeWeek(
          employeeId: 'firebase-employee-1',
          weekId: '2026-W33',
          listId: garaClosing,
        )
        .first;
    expect(otherWeek.map((c) => c.id), ['comp-other-week']);

    final weekLocation = await repos.cleaning
        .watchCompletionsForWeekLocation(
          weekId: '2026-W32',
          location: 'Gara',
          listId: garaClosing,
        )
        .first;
    expect(weekLocation, hasLength(2));

    final avantgarden = await repos.cleaning.watchTasksForList(agClosing).first;
    expect(avantgarden.single.title, 'a da cu matura in depozit');
    expect(avantgarden.single.location, 'Avantgarden');
    expect(avantgarden.single.listId, agClosing);
  });

  test('propagates HTTP errors', () async {
    final repos = buildVccRepos(vccApiMock(statusCode: 500));
    await expectLater(
      repos.cleaning.watchTasksForList('Gara_closing').first,
      throwsA(
        isA<ApiHttpException>().having((e) => e.statusCode, 'statusCode', 500),
      ),
    );
  });

  test('does not call the API when no user is signed in', () async {
    var calls = 0;
    final api = buildTestApiClient(
      tokenSource: FakeTokenSource([null]),
      httpClient: MockClient((request) async {
        calls += 1;
        return http.Response('{"lists":[],"tasks":[],"completions":[]}', 200);
      }),
    );
    final repository = CleaningRepository(
      apiClient: api,
      usersRepository: UsersRepository(
        apiClient: api,
        locationRepository: LocationRepository(apiClient: api),
      ),
      locationRepository: LocationRepository(apiClient: api),
    );

    await expectLater(
      repository.watchTasksForList('Gara_closing').first,
      throwsA(isA<ApiUnauthenticatedException>()),
    );
    expect(calls, 0);
  });

  test('completion write sends task_id/week_id/completed and no user_id',
      () async {
    final requests = <http.Request>[];
    final repos = buildVccRepos(
      vccApiMock(
        onWrite: (request) async {
          requests.add(request);
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/cleaning/completions');
          return http.Response(
            '{"id":"comp-new","user_id":"cb3355e2-1bad-4826-8796-ca1734ce288a",'
            '"task_id":"task-gara-closing-0","week_id":"2026-W40","completed":true,'
            '"completed_at":"2026-08-15T12:00:00.000Z"}',
            200,
          );
        },
      ),
    );

    const task = CleaningTaskModel(
      id: 'task-gara-closing-0',
      listId: 'Gara_closing',
      location: 'Gara',
      title: 'Spalare LAF',
      order: 0,
    );

    await repos.cleaning.setTaskCompletion(
      employeeId: 'firebase-employee-1',
      task: task,
      weekId: '2026-W40',
      completed: true,
    );

    expect(requests, hasLength(1));
    expect(requests.single.body, contains('"task_id":"task-gara-closing-0"'));
    expect(requests.single.body, contains('"week_id":"2026-W40"'));
    expect(requests.single.body, contains('"completed":true'));
    expect(requests.single.body.contains('user_id'), isFalse);
    expect(requests.single.body.contains('employeeId'), isFalse);
    expect(requests.single.body.contains('listId'), isFalse);
  });

  test('task create/update/delete/reorder use location+key and task UUID',
      () async {
    final requests = <http.Request>[];
    final repos = buildVccRepos(
      vccApiMock(
        onWrite: (request) async {
          requests.add(request);
          if (request.method == 'POST') {
            return http.Response(
              '{"id":"task-new","list_id":"list-gara-closing","title":"Mop floor",'
              '"sort_order":2,"is_active":true}',
              201,
            );
          }
          if (request.method == 'PATCH') {
            return http.Response(
              '{"id":"task-new","list_id":"list-gara-closing","title":"Mop thoroughly",'
              '"sort_order":2,"is_active":true}',
              200,
            );
          }
          if (request.method == 'DELETE') {
            return http.Response(
              '{"id":"task-new","list_id":"list-gara-closing","title":"Mop thoroughly",'
              '"sort_order":2,"is_active":false}',
              200,
            );
          }
          return http.Response(
            '[{"id":"task-new","list_id":"list-gara-closing","title":"Mop thoroughly",'
            '"sort_order":0,"is_active":true}]',
            200,
          );
        },
      ),
    );

    final created = await repos.cleaning.addTask(
      location: 'Gara',
      listKey: CleaningListKey.closing,
      title: 'Mop floor',
    );
    expect(created.id, 'task-new');
    expect(created.listId, 'Gara_closing');
    expect(created.location, 'Gara');
    expect(created.title, 'Mop floor');
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/cleaning/tasks');
    expect(requests.single.body, contains('"location":"Gara"'));
    expect(requests.single.body, contains('"key":"closing"'));
    expect(requests.single.body, contains('"title":"Mop floor"'));
    expect(requests.single.body.contains('listId'), isFalse);
    expect(requests.single.body.contains('Gara_closing'), isFalse);

    requests.clear();
    await repos.cleaning.updateTaskTitle('task-new', 'Mop thoroughly');
    expect(requests.single.method, 'PATCH');
    expect(requests.single.url.path, '/api/cleaning/tasks/task-new');
    expect(requests.single.body, contains('"title":"Mop thoroughly"'));

    requests.clear();
    await repos.cleaning.reorderTasks([created]);
    expect(requests.single.method, 'PUT');
    expect(requests.single.url.path, '/api/cleaning/tasks/reorder');
    expect(requests.single.body, contains('"ids":["task-new"]'));

    requests.clear();
    await repos.cleaning.deleteTask('task-new');
    expect(requests.single.method, 'DELETE');
    expect(requests.single.url.path, '/api/cleaning/tasks/task-new');
  });

  test('propagates write authorization errors', () async {
    final repos = buildVccRepos(
      vccApiMock(
        onWrite: (request) async {
          return http.Response('{"error":"forbidden"}', 403);
        },
      ),
    );

    await expectLater(
      repos.cleaning.addTask(
        location: 'Gara',
        listKey: CleaningListKey.closing,
        title: 'Nope',
      ),
      throwsA(
        isA<ApiHttpException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.errorCode, 'errorCode', 'forbidden'),
      ),
    );

    await expectLater(
      repos.cleaning.setTaskCompletion(
        employeeId: 'firebase-employee-1',
        task: const CleaningTaskModel(
          id: 'task-gara-closing-0',
          listId: 'Gara_closing',
          location: 'Gara',
          title: 'Spalare LAF',
          order: 0,
        ),
        weekId: '2026-W40',
        completed: true,
      ),
      throwsA(
        isA<ApiHttpException>().having((e) => e.statusCode, 'statusCode', 403),
      ),
    );
  });

  test('cleaning UI and repository do not write Firestore', () {
    const files = [
      'lib/features/cleaning/data/cleaning_repository.dart',
      'lib/features/cleaning/domain/cleaning_task_model.dart',
      'lib/features/cleaning/presentation/cleaning_todo_screen.dart',
      'lib/features/cleaning/presentation/cleaning_lists_admin_screen.dart',
      'lib/features/cleaning/presentation/cleaning_providers.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source.contains('cloud_firestore'), isFalse, reason: path);
      expect(source.contains('FirebaseFirestore'), isFalse, reason: path);
      expect(source.contains("collection('cleaning_tasks')"), isFalse, reason: path);
      expect(
        source.contains("collection('cleaning_completions')"),
        isFalse,
        reason: path,
      );
    }

    final todo = File(
      'lib/features/cleaning/presentation/cleaning_todo_screen.dart',
    ).readAsStringSync();
    expect(todo.contains('setTaskCompletion'), isTrue);
    expect(todo.contains('.set('), isFalse);
    expect(todo.contains('.add('), isFalse);

    final admin = File(
      'lib/features/cleaning/presentation/cleaning_lists_admin_screen.dart',
    ).readAsStringSync();
    expect(admin.contains('addTask'), isTrue);
    expect(admin.contains('updateTaskTitle'), isTrue);
    expect(admin.contains('deleteTask'), isTrue);
    expect(admin.contains('reorderTasks'), isTrue);
    expect(admin.contains('.set('), isFalse);
    expect(admin.contains('.update('), isFalse);
    expect(admin.contains('.delete('), isFalse);
  });
}
