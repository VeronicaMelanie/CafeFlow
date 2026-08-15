import '../../../core/api/api_datetime.dart';

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

  factory CleaningTaskModel.fromApiJson(
    Map<String, dynamic> json, {
    required String flutterListId,
    required String locationName,
  }) {
    return CleaningTaskModel(
      id: json['id']?.toString() ?? '',
      listId: flutterListId,
      location: locationName,
      title: json['title']?.toString() ?? '',
      order: (json['sort_order'] as num?)?.toInt() ?? 0,
      active: json['is_active'] != false,
    );
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

  factory CleaningTaskCompletionModel.fromApiJson(
    Map<String, dynamic> json, {
    required String firebaseUid,
    required String flutterListId,
    required String locationName,
  }) {
    final completedAt = json['completed_at']?.toString();
    return CleaningTaskCompletionModel(
      id: json['id']?.toString() ?? '',
      employeeId: firebaseUid,
      taskId: json['task_id']?.toString() ?? '',
      listId: flutterListId,
      location: locationName,
      weekId: json['week_id']?.toString() ?? '',
      completed: json['completed'] == true,
      completedAt: completedAt == null || completedAt.isEmpty
          ? null
          : ApiDateTime.parseTimestamptz(completedAt),
    );
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
