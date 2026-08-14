import 'package:cloud_firestore/cloud_firestore.dart';

/// Permanent task definition for a cleaning list.
class CleaningTaskModel {
  final String id;
  final String listId;
  final String location;
  final String title;
  final int order;
  final bool active;

  const CleaningTaskModel({
    required this.id,
    required this.listId,
    required this.location,
    required this.title,
    required this.order,
    this.active = true,
  });

  factory CleaningTaskModel.fromMap(Map<String, dynamic> map, String id) {
    return CleaningTaskModel(
      id: id,
      listId: map['listId']?.toString() ?? '',
      location: map['location']?.toString() ?? 'Gara',
      title: map['title']?.toString() ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      active: map['active'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'listId': listId,
      'location': location,
      'title': title,
      'order': order,
      'active': active,
    };
  }

  CleaningTaskModel copyWith({
    String? title,
    int? order,
    bool? active,
  }) {
    return CleaningTaskModel(
      id: id,
      listId: listId,
      location: location,
      title: title ?? this.title,
      order: order ?? this.order,
      active: active ?? this.active,
    );
  }
}

/// Weekly completion state for one employee task.
class CleaningTaskCompletionModel {
  final String id;
  final String employeeId;
  final String taskId;
  final String listId;
  final String location;
  final String weekId;
  final bool completed;
  final DateTime? completedAt;

  const CleaningTaskCompletionModel({
    required this.id,
    required this.employeeId,
    required this.taskId,
    required this.listId,
    required this.location,
    required this.weekId,
    required this.completed,
    this.completedAt,
  });

  static String docId(String employeeId, String taskId, String weekId) =>
      '${employeeId}_${taskId}_$weekId';

  factory CleaningTaskCompletionModel.fromMap(Map<String, dynamic> map, String id) {
    return CleaningTaskCompletionModel(
      id: id,
      employeeId: map['employeeId']?.toString() ?? '',
      taskId: map['taskId']?.toString() ?? '',
      listId: map['listId']?.toString() ?? '',
      location: map['location']?.toString() ?? 'Gara',
      weekId: map['weekId']?.toString() ?? '',
      completed: map['completed'] == true,
      completedAt: map['completedAt'] is Timestamp
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'taskId': taskId,
      'listId': listId,
      'location': location,
      'weekId': weekId,
      'completed': completed,
      if (completedAt != null)
        'completedAt': Timestamp.fromDate(completedAt!),
    };
  }
}

/// Task plus completion flag for the current week.
class CleaningTaskViewModel {
  final CleaningTaskModel task;
  final bool completed;

  const CleaningTaskViewModel({
    required this.task,
    required this.completed,
  });
}

/// Employee progress for admin monitoring.
class CleaningEmployeeProgress {
  final String employeeId;
  final String employeeName;
  final int completedCount;
  final int totalCount;

  const CleaningEmployeeProgress({
    required this.employeeId,
    required this.employeeName,
    required this.completedCount,
    required this.totalCount,
  });

  bool get isComplete => totalCount > 0 && completedCount >= totalCount;
  bool get isPartial =>
      totalCount > 0 && completedCount > 0 && completedCount < totalCount;
  bool get isNotStarted => completedCount == 0;
}
