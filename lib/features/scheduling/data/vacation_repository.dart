import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_datetime.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import '../../auth/data/users_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/vacation_model.dart';
import '../utils/vacation_list_utils.dart';

class VacationRepository {
  VacationRepository({
    ApiClient? apiClient,
    UsersRepository? usersRepository,
    bool testMode = false,
  })  : _api = apiClient,
        _users = usersRepository,
        _testMode = testMode;

  @visibleForTesting
  VacationRepository.test() : this(testMode: true);

  final ApiClient? _api;
  final UsersRepository? _users;
  final bool _testMode;

  ApiClient get _client {
    final api = _api;
    if (api == null) {
      throw const ApiException('Vacations API client is not configured');
    }
    return api;
  }

  UsersRepository get _usersRepo {
    final users = _users;
    if (users == null) {
      throw const ApiException('Vacations users repository is not configured');
    }
    return users;
  }

  /// GET /api/vacations returns all rows; filter user/status client-side.
  Future<List<VacationModel>> getAllVacations() async {
    if (_testMode) return const [];
    final json = await _client.getJson('/api/vacations');
    if (json is! List) {
      throw const ApiException('Expected a JSON array from /api/vacations');
    }

    final usersByPostgresId = await _usersRepo.byPostgresId();
    final result = <VacationModel>[];
    for (final item in json) {
      final map = Map<String, dynamic>.from(item as Map);
      final postgresUserId = map['user_id']?.toString() ?? '';
      final user = usersByPostgresId[postgresUserId];
      if (user == null) continue;
      result.add(
        VacationModel.fromApiJson(
          map,
          firebaseUid: user.uid,
          userName: user.name,
        ),
      );
    }
    return result;
  }

  Stream<List<VacationModel>> getVacationsForUser(String userId) {
    return Stream.fromFuture(_vacationsForUser(userId));
  }

  Future<List<VacationModel>> _vacationsForUser(String userId) async {
    final all = await getAllVacations();
    return VacationListUtils.sortByRequestDateNewestFirst(
      all.where((vacation) => vacation.userId == userId).toList(),
    );
  }

  Stream<List<VacationModel>> getAllPendingVacations() {
    return Stream.fromFuture(_pendingVacations());
  }

  Future<List<VacationModel>> _pendingVacations() async {
    final all = await getAllVacations();
    return VacationListUtils.filterByStatus(all, 'pending');
  }

  Future<void> requestVacation(VacationModel vacation) async {
    if (_testMode) return;
    await _client.postJson(
      '/api/vacations',
      body: {
        'start_on': ApiDateTime.formatDateOnly(vacation.startDate),
        'end_on': ApiDateTime.formatDateOnly(vacation.endDate),
      },
    );
  }

  Future<void> updateVacationStatus(
    VacationModel vacation,
    String status, {
    String? comment,
  }) async {
    if (_testMode) return;
    if (vacation.id.isEmpty) {
      throw const ApiException('Vacation id is required');
    }
    final body = <String, dynamic>{'status': status};
    if (comment != null) {
      body['admin_comment'] = comment;
    }
    await _client.patchJson('/api/vacations/${vacation.id}', body: body);
  }
}

final vacationRepositoryProvider = Provider((ref) {
  return VacationRepository(
    apiClient: ref.watch(apiClientProvider),
    usersRepository: ref.watch(usersRepositoryProvider),
  );
});
