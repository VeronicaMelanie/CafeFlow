import 'package:fivetogo_scheduler/core/api/api_client.dart';
import 'package:fivetogo_scheduler/features/auth/data/users_repository.dart';
import 'package:fivetogo_scheduler/features/locations/data/location_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/data/availability_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/data/scheduling_config_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/data/shift_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'api_test_harness.dart';

const locationsJson = '''
[
  {
    "id": "ff63f35a-ddd1-449e-9021-33ee78e2261a",
    "code": "gara",
    "name": "Gara",
    "is_active": true,
    "opened_on": null,
    "closed_on": null
  },
  {
    "id": "cc643d67-081b-44e1-b4c0-c0194fbb9aab",
    "code": "avantgarden",
    "name": "Avantgarden",
    "is_active": true,
    "opened_on": null,
    "closed_on": null
  }
]
''';

const usersJson = '''
[
  {
    "id": "cb3355e2-1bad-4826-8796-ca1734ce288a",
    "firebase_uid": "firebase-employee-1",
    "email": "employee@example.com",
    "name": "Veronica",
    "role": "employee",
    "contract_type": "full_time",
    "employment_started_on": "2025-06-30",
    "monthly_target_hours": 160,
    "needs_contract_type": false,
    "auth_provider": "google"
  },
  {
    "id": "2583717c-1d7a-4901-8788-a8096cfdf8e3",
    "firebase_uid": "firebase-admin-1",
    "email": "admin@example.com",
    "name": "Malina",
    "role": "admin",
    "contract_type": "part_time",
    "employment_started_on": null,
    "monthly_target_hours": 80,
    "needs_contract_type": true,
    "auth_provider": "email"
  }
]
''';

const schedulingJson = '''
[
  {
    "id": "sched-global-sep",
    "year": 2026,
    "month": 9,
    "location_id": null,
    "scheduling_enabled": true,
    "locked_month": false,
    "enabled_by": "2583717c-1d7a-4901-8788-a8096cfdf8e3",
    "enabled_at": "2026-08-14T07:28:02.526Z",
    "max_hours_per_day": null,
    "max_employees_per_shift": null
  },
  {
    "id": "sched-gara-sep",
    "year": 2026,
    "month": 9,
    "location_id": "ff63f35a-ddd1-449e-9021-33ee78e2261a",
    "scheduling_enabled": false,
    "locked_month": true,
    "enabled_by": "2583717c-1d7a-4901-8788-a8096cfdf8e3",
    "enabled_at": "2026-08-14T08:00:00.000Z",
    "max_hours_per_day": 18,
    "max_employees_per_shift": 3
  },
  {
    "id": "sched-unknown-loc",
    "year": 2026,
    "month": 9,
    "location_id": "00000000-0000-0000-0000-000000000000",
    "scheduling_enabled": true,
    "locked_month": false,
    "enabled_by": null,
    "enabled_at": null,
    "max_hours_per_day": null,
    "max_employees_per_shift": null
  }
]
''';

const availabilityJson = '''
[
  {
    "id": "avail-full-sep",
    "user_id": "cb3355e2-1bad-4826-8796-ca1734ce288a",
    "work_date": "2026-09-10",
    "shift_type": "full_time",
    "custom_start_time": null,
    "custom_end_time": null,
    "submitted_at": "2026-08-09T08:32:15.873Z"
  },
  {
    "id": "avail-custom-sep",
    "user_id": "cb3355e2-1bad-4826-8796-ca1734ce288a",
    "work_date": "2026-09-23",
    "shift_type": "custom_hours",
    "custom_start_time": "04:00:00.000",
    "custom_end_time": "10:00:00.000",
    "submitted_at": "2026-08-09T08:32:16.801Z"
  },
  {
    "id": "avail-aug",
    "user_id": "cb3355e2-1bad-4826-8796-ca1734ce288a",
    "work_date": "2026-08-17",
    "shift_type": "full_time",
    "custom_start_time": null,
    "custom_end_time": null,
    "submitted_at": "2026-07-16T18:52:40.207Z"
  },
  {
    "id": "avail-admin-sep",
    "user_id": "2583717c-1d7a-4901-8788-a8096cfdf8e3",
    "work_date": "2026-09-10",
    "shift_type": "full_time",
    "custom_start_time": null,
    "custom_end_time": null,
    "submitted_at": "2026-08-09T09:00:00.000Z"
  },
  {
    "id": "avail-unknown-user",
    "user_id": "00000000-0000-0000-0000-000000000000",
    "work_date": "2026-09-10",
    "shift_type": "full_time",
    "custom_start_time": null,
    "custom_end_time": null,
    "submitted_at": "2026-08-09T09:00:00.000Z"
  }
]
''';

const shiftsJson = '''
[
  {
    "id": "shift-gara-sep",
    "user_id": "cb3355e2-1bad-4826-8796-ca1734ce288a",
    "location_id": "ff63f35a-ddd1-449e-9021-33ee78e2261a",
    "work_date": "2026-09-10",
    "start_at": "2026-09-10T04:00:00.000Z",
    "end_at": "2026-09-10T15:00:00.000Z",
    "type": "FULL",
    "status": "approved"
  },
  {
    "id": "shift-ag-sep",
    "user_id": "cb3355e2-1bad-4826-8796-ca1734ce288a",
    "location_id": "cc643d67-081b-44e1-b4c0-c0194fbb9aab",
    "work_date": "2026-09-11",
    "start_at": "2026-09-11T05:00:00.000Z",
    "end_at": "2026-09-11T10:00:00.000Z",
    "type": "CUSTOM",
    "status": "pending"
  },
  {
    "id": "shift-gara-aug",
    "user_id": "cb3355e2-1bad-4826-8796-ca1734ce288a",
    "location_id": "ff63f35a-ddd1-449e-9021-33ee78e2261a",
    "work_date": "2026-08-01",
    "start_at": "2026-08-01T04:00:00.000Z",
    "end_at": "2026-08-01T15:00:00.000Z",
    "type": "FULL",
    "status": "approved"
  },
  {
    "id": "shift-unknown-user",
    "user_id": "00000000-0000-0000-0000-000000000000",
    "location_id": "ff63f35a-ddd1-449e-9021-33ee78e2261a",
    "work_date": "2026-09-12",
    "start_at": "2026-09-12T04:00:00.000Z",
    "end_at": "2026-09-12T15:00:00.000Z",
    "type": "FULL",
    "status": "approved"
  }
]
''';

MockClient schedulingApiMock({
  String locations = locationsJson,
  String users = usersJson,
  String scheduling = schedulingJson,
  String availability = availabilityJson,
  String shifts = shiftsJson,
  int statusCode = 200,
  List<String>? capturedPaths,
  Future<http.Response> Function(http.Request request)? onWrite,
}) {
  return MockClient((request) async {
    capturedPaths?.add(request.url.path);
    if (onWrite != null && request.method != 'GET') {
      return onWrite(request);
    }
    if (statusCode != 200) {
      return http.Response('{"error":"internal_error"}', statusCode);
    }
    switch (request.url.path) {
      case '/api/locations':
        return http.Response(locations, 200);
      case '/api/users':
        return http.Response(users, 200);
      case '/api/scheduling':
        return http.Response(scheduling, 200);
      case '/api/availability':
        return http.Response(availability, 200);
      case '/api/shifts':
        return http.Response(shifts, 200);
      default:
        return http.Response('not found', 404);
    }
  });
}

class SchedulingApiRepos {
  SchedulingApiRepos(this.api)
      : locations = LocationRepository(apiClient: api),
        users = UsersRepository(
          apiClient: api,
          locationRepository: LocationRepository(apiClient: api),
        );

  final ApiClient api;
  final LocationRepository locations;
  final UsersRepository users;

  AvailabilityRepository get availability => AvailabilityRepository(
        apiClient: api,
        usersRepository: users,
      );

  ShiftRepository get shifts => ShiftRepository(
        apiClient: api,
        usersRepository: users,
        locationRepository: locations,
      );

  SchedulingConfigRepository get scheduling => SchedulingConfigRepository(
        apiClient: api,
        usersRepository: users,
        locationRepository: locations,
      );
}

SchedulingApiRepos buildSchedulingRepos(MockClient httpClient) {
  return SchedulingApiRepos(buildTestApiClient(httpClient: httpClient));
}
