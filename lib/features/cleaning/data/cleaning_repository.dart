import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/users_repository.dart';
import '../../locations/data/location_repository.dart';
import '../../locations/utils/location_catalog.dart';
import '../domain/cleaning_list_key.dart';
import '../domain/cleaning_task_model.dart';
import '../utils/cleaning_week_utils.dart';

class _MemoryCleaningStore {
  final Map<String, CleaningTaskModel> tasks = {};
  final Map<String, CleaningTaskCompletionModel> completions = {};
  final StreamController<void> _controller = StreamController.broadcast();

  Stream<void> get changes => _controller.stream;

  void notify() => _controller.add(null);

  void dispose() => _controller.close();
}

class _CleaningListRef {
  const _CleaningListRef({
    required this.id,
    required this.locationName,
    required this.flutterListId,
  });

  final String id;
  final String locationName;
  final String flutterListId;
}

class _CleaningBundle {
  const _CleaningBundle({
    required this.tasks,
    required this.completions,
  });

  final List<CleaningTaskModel> tasks;
  final List<CleaningTaskCompletionModel> completions;
}

class CleaningRepository {
  CleaningRepository({
    ApiClient? apiClient,
    UsersRepository? usersRepository,
    LocationRepository? locationRepository,
  })  : _api = apiClient,
        _users = usersRepository,
        _locations = locationRepository,
        _memory = null;

  @visibleForTesting
  CleaningRepository.test()
      : _api = null,
        _users = null,
        _locations = null,
        _memory = _MemoryCleaningStore();

  final ApiClient? _api;
  final UsersRepository? _users;
  final LocationRepository? _locations;
  final _MemoryCleaningStore? _memory;

  ApiClient get _client {
    final api = _api;
    if (api == null) {
      throw const ApiException('Cleaning API client is not configured');
    }
    return api;
  }

  Future<_CleaningBundle>? _bundleInFlight;

  /// GET /api/cleaning returns lists + tasks + completions; filter client-side.
  Future<_CleaningBundle> _loadBundle() async {
    final pending = _bundleInFlight;
    if (pending != null) return pending;
    final future = _fetchBundle();
    _bundleInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_bundleInFlight, future)) {
        _bundleInFlight = null;
      }
    }
  }

  Future<_CleaningBundle> _fetchBundle() async {
    final users = _users;
    final locations = _locations;
    if (users == null || locations == null) {
      throw const ApiException('Cleaning API client is not configured');
    }

    final json = await _client.getJson('/api/cleaning');
    if (json is! Map) {
      throw const ApiException('Expected a JSON object from /api/cleaning');
    }
    final payload = Map<String, dynamic>.from(json);
    final listsJson = payload['lists'];
    final tasksJson = payload['tasks'];
    final completionsJson = payload['completions'];
    if (listsJson is! List || tasksJson is! List || completionsJson is! List) {
      throw const ApiException('GET /api/cleaning is missing lists/tasks/completions');
    }

    final catalog = await locations.getLocations();
    final usersByPostgresId = await users.byPostgresId();
    final listsById = <String, _CleaningListRef>{};
    for (final item in listsJson) {
      final map = Map<String, dynamic>.from(item as Map);
      final locationId = map['location_id']?.toString() ?? '';
      final key = map['key']?.toString() ?? '';
      final location = LocationCatalog.byId(catalog, locationId);
      if (location == null || key.isEmpty) continue;
      final listKey = CleaningListKey.fromStorage(key);
      listsById[map['id']?.toString() ?? ''] = _CleaningListRef(
        id: map['id']?.toString() ?? '',
        locationName: location.name,
        flutterListId: CleaningListKey.listId(location.name, listKey),
      );
    }

    final tasks = <CleaningTaskModel>[];
    final tasksById = <String, CleaningTaskModel>{};
    for (final item in tasksJson) {
      final map = Map<String, dynamic>.from(item as Map);
      final list = listsById[map['list_id']?.toString() ?? ''];
      if (list == null) continue;
      final task = CleaningTaskModel.fromApiJson(
        map,
        flutterListId: list.flutterListId,
        locationName: list.locationName,
      );
      tasks.add(task);
      tasksById[task.id] = task;
    }

    final completions = <CleaningTaskCompletionModel>[];
    for (final item in completionsJson) {
      final map = Map<String, dynamic>.from(item as Map);
      final user = usersByPostgresId[map['user_id']?.toString() ?? ''];
      final task = tasksById[map['task_id']?.toString() ?? ''];
      if (user == null || task == null) continue;
      completions.add(
        CleaningTaskCompletionModel.fromApiJson(
          map,
          firebaseUid: user.uid,
          flutterListId: task.listId,
          locationName: task.location,
        ),
      );
    }

    return _CleaningBundle(tasks: tasks, completions: completions);
  }

  Stream<List<CleaningTaskModel>> watchTasksForList(String listId) {
    if (_memory != null) {
      return _memory!.changes.asyncMap((_) async {
        return _memory!.tasks.values
            .where((task) => task.listId == listId && task.active)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      }).startWith(_sortedTasksForList(listId));
    }

    return Stream.fromFuture(_apiTasksForList(listId));
  }

  Future<List<CleaningTaskModel>> _apiTasksForList(String listId) async {
    final tasks = (await _loadBundle()).tasks
        .where((task) => task.listId == listId && task.active)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return tasks;
  }

  Stream<List<CleaningTaskCompletionModel>> watchCompletionsForEmployeeWeek({
    required String employeeId,
    required String weekId,
    required String listId,
  }) {
    if (_memory != null) {
      return _memory!.changes.asyncMap((_) async {
        return _memory!.completions.values
            .where(
              (item) =>
                  item.employeeId == employeeId &&
                  item.weekId == weekId &&
                  item.listId == listId,
            )
            .toList();
      }).startWith(_completionsFor(employeeId, weekId, listId));
    }

    return Stream.fromFuture(_apiCompletionsForEmployeeWeek(
      employeeId: employeeId,
      weekId: weekId,
      listId: listId,
    ));
  }

  Future<List<CleaningTaskCompletionModel>> _apiCompletionsForEmployeeWeek({
    required String employeeId,
    required String weekId,
    required String listId,
  }) async {
    return (await _loadBundle()).completions
        .where(
          (item) =>
              item.employeeId == employeeId &&
              item.weekId == weekId &&
              item.listId == listId,
        )
        .toList();
  }

  Stream<List<CleaningTaskCompletionModel>> watchCompletionsForWeekLocation({
    required String weekId,
    required String location,
    required String listId,
  }) {
    if (_memory != null) {
      return _memory!.changes.asyncMap((_) async {
        return _memory!.completions.values
            .where(
              (item) =>
                  item.weekId == weekId &&
                  item.location == location &&
                  item.listId == listId,
            )
            .toList();
      }).startWith(
        _memory!.completions.values
            .where(
              (item) =>
                  item.weekId == weekId &&
                  item.location == location &&
                  item.listId == listId,
            )
            .toList(),
      );
    }

    return Stream.fromFuture(_apiCompletionsForWeekLocation(
      weekId: weekId,
      location: location,
      listId: listId,
    ));
  }

  Future<List<CleaningTaskCompletionModel>> _apiCompletionsForWeekLocation({
    required String weekId,
    required String location,
    required String listId,
  }) async {
    return (await _loadBundle()).completions
        .where(
          (item) =>
              item.weekId == weekId &&
              item.location == location &&
              item.listId == listId,
        )
        .toList();
  }

  Future<void> setTaskCompletion({
    required String employeeId,
    required CleaningTaskModel task,
    required String weekId,
    required bool completed,
  }) async {
    final completion = CleaningTaskCompletionModel(
      id: CleaningTaskCompletionModel.docId(employeeId, task.id, weekId),
      employeeId: employeeId,
      taskId: task.id,
      listId: task.listId,
      location: task.location,
      weekId: weekId,
      completed: completed,
      completedAt: completed ? DateTime.now() : null,
    );

    if (_memory != null) {
      _memory!.completions[completion.id] = completion;
      _memory!.notify();
      return;
    }

    await _client.putJson(
      '/api/cleaning/completions',
      body: {
        'task_id': task.id,
        'week_id': weekId,
        'completed': completed,
      },
    );
  }

  Future<CleaningTaskModel> addTask({
    required String location,
    required CleaningListKey listKey,
    required String title,
  }) async {
    final listId = CleaningListKey.listId(location, listKey);
    final trimmed = title.trim();

    if (_memory != null) {
      final existing = _sortedTasksForList(listId);
      final order = existing.isEmpty
          ? 0
          : existing.map((task) => task.order).reduce((a, b) => a > b ? a : b) + 1;
      final id = 'task_${_memory!.tasks.length + 1}';
      final stored = CleaningTaskModel(
        id: id,
        listId: listId,
        location: location,
        title: trimmed,
        order: order,
      );
      _memory!.tasks[id] = stored;
      _memory!.notify();
      return stored;
    }

    final json = await _client.postJson(
      '/api/cleaning/tasks',
      body: {
        'location': location,
        'key': listKey.name,
        'title': trimmed,
      },
    );
    if (json is! Map) {
      throw const ApiException('Expected a JSON object from POST /api/cleaning/tasks');
    }
    return CleaningTaskModel.fromApiJson(
      Map<String, dynamic>.from(json),
      flutterListId: listId,
      locationName: location,
    );
  }

  Future<void> updateTaskTitle(String taskId, String title) async {
    final trimmed = title.trim();
    if (_memory != null) {
      final existing = _memory!.tasks[taskId];
      if (existing == null) return;
      _memory!.tasks[taskId] = existing.copyWith(title: trimmed);
      _memory!.notify();
      return;
    }
    await _client.patchJson(
      '/api/cleaning/tasks/$taskId',
      body: {'title': trimmed},
    );
  }

  Future<void> deleteTask(String taskId) async {
    if (_memory != null) {
      final existing = _memory!.tasks[taskId];
      if (existing == null) return;
      _memory!.tasks[taskId] = existing.copyWith(active: false);
      _memory!.notify();
      return;
    }
    await _client.delete('/api/cleaning/tasks/$taskId');
  }

  Future<void> reorderTasks(List<CleaningTaskModel> orderedTasks) async {
    if (_memory != null) {
      for (var index = 0; index < orderedTasks.length; index++) {
        final taskId = orderedTasks[index].id;
        final existing = _memory!.tasks[taskId];
        if (existing == null) continue;
        _memory!.tasks[taskId] = existing.copyWith(order: index);
      }
      _memory!.notify();
      return;
    }

    if (orderedTasks.isEmpty) return;
    await _client.putJson(
      '/api/cleaning/tasks/reorder',
      body: {
        'ids': orderedTasks.map((task) => task.id).toList(),
      },
    );
  }

  List<CleaningTaskModel> _sortedTasksForList(String listId) {
    return _memory!.tasks.values
        .where((task) => task.listId == listId && task.active)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  List<CleaningTaskCompletionModel> _completionsFor(
    String employeeId,
    String weekId,
    String listId,
  ) {
    return _memory!.completions.values
        .where(
          (item) =>
              item.employeeId == employeeId &&
              item.weekId == weekId &&
              item.listId == listId,
        )
        .toList();
  }
}

extension<T> on Stream<T> {
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}

List<CleaningTaskViewModel> mergeTasksWithCompletions({
  required List<CleaningTaskModel> tasks,
  required List<CleaningTaskCompletionModel> completions,
}) {
  final completionByTask = {
    for (final completion in completions) completion.taskId: completion.completed,
  };
  return tasks
      .map(
        (task) => CleaningTaskViewModel(
          task: task,
          completed: completionByTask[task.id] == true,
        ),
      )
      .toList();
}

CleaningEmployeeProgress buildEmployeeProgress({
  required String employeeId,
  required String employeeName,
  required List<CleaningTaskModel> tasks,
  required List<CleaningTaskCompletionModel> completions,
}) {
  final completedTaskIds = completions
      .where((completion) => completion.completed)
      .map((completion) => completion.taskId)
      .toSet();
  final completedCount =
      tasks.where((task) => completedTaskIds.contains(task.id)).length;
  return CleaningEmployeeProgress(
    employeeId: employeeId,
    employeeName: employeeName,
    completedCount: completedCount,
    totalCount: tasks.length,
  );
}

String currentCleaningWeekId([DateTime? date]) =>
    CleaningWeekUtils.weekIdFor(date ?? DateTime.now());
