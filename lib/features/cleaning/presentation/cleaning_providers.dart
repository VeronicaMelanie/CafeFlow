import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../locations/presentation/location_providers.dart';
import '../../scheduling/presentation/scheduling_providers.dart';
import '../data/cleaning_repository.dart';
import '../domain/cleaning_list_key.dart';
import '../domain/cleaning_task_model.dart';

final cleaningRepositoryProvider = Provider<CleaningRepository>((ref) {
  return CleaningRepository(
    apiClient: ref.watch(apiClientProvider),
    usersRepository: ref.watch(usersRepositoryProvider),
    locationRepository: ref.watch(locationRepositoryProvider),
  );
});

final cleaningSelectedListKeyProvider =
    StateProvider<CleaningListKey>((ref) => CleaningListKey.closing);

final cleaningWeekIdProvider = Provider<String>((ref) {
  return currentCleaningWeekId();
});

final cleaningTasksForListProvider =
    StreamProvider.family<List<CleaningTaskModel>, String>((ref, listId) {
  return ref.watch(cleaningRepositoryProvider).watchTasksForList(listId);
});

final cleaningTaskViewsProvider =
    StreamProvider.family<List<CleaningTaskViewModel>, CleaningListQuery>((
  ref,
  query,
) {
  final repository = ref.watch(cleaningRepositoryProvider);
  final tasksStream = repository.watchTasksForList(query.listId);
  final completionsStream = repository.watchCompletionsForEmployeeWeek(
    employeeId: query.employeeId,
    weekId: query.weekId,
    listId: query.listId,
  );

  return tasksStream.asyncExpand((tasks) {
    return completionsStream.map(
      (completions) => mergeTasksWithCompletions(
        tasks: tasks,
        completions: completions,
      ),
    );
  });
});

final cleaningAdminCompletionsProvider =
    StreamProvider.family<List<CleaningTaskCompletionModel>, CleaningListQuery>((
  ref,
  query,
) {
  return ref
      .watch(cleaningRepositoryProvider)
      .watchCompletionsForWeekLocation(
        weekId: query.weekId,
        location: query.location,
        listId: query.listId,
      );
});

class CleaningListQuery {
  final String listId;
  final String location;
  final String employeeId;
  final String weekId;

  const CleaningListQuery({
    required this.listId,
    required this.location,
    required this.employeeId,
    required this.weekId,
  });

  @override
  bool operator ==(Object other) {
    return other is CleaningListQuery &&
        other.listId == listId &&
        other.location == location &&
        other.employeeId == employeeId &&
        other.weekId == weekId;
  }

  @override
  int get hashCode => Object.hash(listId, location, employeeId, weekId);
}

CleaningListQuery cleaningQueryForEmployee(
  WidgetRef ref, {
  required CleaningListKey listKey,
  required String employeeId,
  String? location,
}) {
  final String resolvedLocation =
      location ?? ref.watch(selectedLocationProvider);
  final weekId = ref.watch(cleaningWeekIdProvider);
  return CleaningListQuery(
    listId: CleaningListKey.listId(resolvedLocation, listKey),
    location: resolvedLocation,
    employeeId: employeeId,
    weekId: weekId,
  );
}

CleaningListQuery cleaningQueryForAdmin(
  WidgetRef ref, {
  required CleaningListKey listKey,
  required String location,
}) {
  return CleaningListQuery(
    listId: CleaningListKey.listId(location, listKey),
    location: location,
    employeeId: '',
    weekId: ref.watch(cleaningWeekIdProvider),
  );
}
