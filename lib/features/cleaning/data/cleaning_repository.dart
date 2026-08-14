import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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

class CleaningRepository {
  CleaningRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _memory = null;

  @visibleForTesting
  CleaningRepository.test()
      : _firestore = null,
        _memory = _MemoryCleaningStore();

  final FirebaseFirestore? _firestore;
  final _MemoryCleaningStore? _memory;

  CollectionReference<Map<String, dynamic>> get _tasksCollection =>
      _firestore!.collection('cleaning_tasks');

  CollectionReference<Map<String, dynamic>> get _completionsCollection =>
      _firestore!.collection('cleaning_completions');

  Stream<List<CleaningTaskModel>> watchTasksForList(String listId) {
    if (_memory != null) {
      return _memory!.changes.asyncMap((_) async {
        return _memory!.tasks.values
            .where((task) => task.listId == listId && task.active)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      }).startWith(_sortedTasksForList(listId));
    }

    return _tasksCollection
        .where('listId', isEqualTo: listId)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final tasks = snapshot.docs
          .map((doc) => CleaningTaskModel.fromMap(doc.data(), doc.id))
          .toList();
      tasks.sort((a, b) => a.order.compareTo(b.order));
      return tasks;
    });
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

    return _completionsCollection
        .where('employeeId', isEqualTo: employeeId)
        .where('weekId', isEqualTo: weekId)
        .where('listId', isEqualTo: listId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CleaningTaskCompletionModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
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

    return _completionsCollection
        .where('weekId', isEqualTo: weekId)
        .where('location', isEqualTo: location)
        .where('listId', isEqualTo: listId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CleaningTaskCompletionModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
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

    await _completionsCollection
        .doc(completion.id)
        .set(completion.toMap(), SetOptions(merge: true));
  }

  Future<CleaningTaskModel> addTask({
    required String location,
    required CleaningListKey listKey,
    required String title,
  }) async {
    final listId = CleaningListKey.listId(location, listKey);
    final existing = await _currentTasks(listId);
    final order = existing.isEmpty
        ? 0
        : existing.map((task) => task.order).reduce((a, b) => a > b ? a : b) + 1;

    final task = CleaningTaskModel(
      id: '',
      listId: listId,
      location: location,
      title: title.trim(),
      order: order,
    );

    if (_memory != null) {
      final id = 'task_${_memory!.tasks.length + 1}';
      final stored = CleaningTaskModel(
        id: id,
        listId: task.listId,
        location: task.location,
        title: task.title,
        order: task.order,
      );
      _memory!.tasks[id] = stored;
      _memory!.notify();
      return stored;
    }

    final doc = await _tasksCollection.add(task.toMap());
    return CleaningTaskModel.fromMap(task.toMap(), doc.id);
  }

  Future<void> updateTaskTitle(String taskId, String title) async {
    if (_memory != null) {
      final existing = _memory!.tasks[taskId];
      if (existing == null) return;
      _memory!.tasks[taskId] = existing.copyWith(title: title.trim());
      _memory!.notify();
      return;
    }
    await _tasksCollection.doc(taskId).update({'title': title.trim()});
  }

  Future<void> deleteTask(String taskId) async {
    if (_memory != null) {
      _memory!.tasks.remove(taskId);
      _memory!.notify();
      return;
    }
    await _tasksCollection.doc(taskId).update({'active': false});
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

    final batch = _firestore!.batch();
    for (var index = 0; index < orderedTasks.length; index++) {
      batch.update(
        _tasksCollection.doc(orderedTasks[index].id),
        {'order': index},
      );
    }
    await batch.commit();
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

  Future<List<CleaningTaskModel>> _currentTasks(String listId) async {
    if (_memory != null) {
      return _sortedTasksForList(listId);
    }
    final snapshot = await _tasksCollection
        .where('listId', isEqualTo: listId)
        .where('active', isEqualTo: true)
        .get();
    final tasks = snapshot.docs
        .map((doc) => CleaningTaskModel.fromMap(doc.data(), doc.id))
        .toList();
    tasks.sort((a, b) => a.order.compareTo(b.order));
    return tasks;
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
