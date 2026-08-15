import 'package:fivetogo_scheduler/core/api/api_client.dart';
import 'package:fivetogo_scheduler/features/auth/data/users_repository.dart';
import 'package:fivetogo_scheduler/features/cleaning/data/cleaning_repository.dart';
import 'package:fivetogo_scheduler/features/consumption/data/consumption_repository.dart';
import 'package:fivetogo_scheduler/features/locations/data/location_repository.dart';
import 'package:fivetogo_scheduler/features/products/data/product_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/data/vacation_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'api_test_harness.dart';
import 'scheduling_api_fixtures.dart';

const productsJson = '''
[
  {
    "id": "prod-coffee",
    "name": "Espresso",
    "category_id": null,
    "sku": "esp",
    "is_active": true
  }
]
''';

const vacationsJson = '''
[
  {
    "id": "vac-approved",
    "user_id": "cb3355e2-1bad-4826-8796-ca1734ce288a",
    "start_on": "2026-08-26",
    "end_on": "2026-08-29",
    "status": "approved",
    "admin_comment": null,
    "requested_at": "2026-07-16T15:00:33.092Z"
  },
  {
    "id": "vac-pending-new",
    "user_id": "cb3355e2-1bad-4826-8796-ca1734ce288a",
    "start_on": "2026-09-16",
    "end_on": "2026-09-21",
    "status": "pending",
    "admin_comment": "Need coverage",
    "requested_at": "2026-08-14T07:26:15.347Z"
  },
  {
    "id": "vac-rejected",
    "user_id": "cb3355e2-1bad-4826-8796-ca1734ce288a",
    "start_on": "2026-06-17",
    "end_on": "2026-06-18",
    "status": "rejected",
    "admin_comment": null,
    "requested_at": "2026-05-27T10:32:52.450Z"
  },
  {
    "id": "vac-admin-pending",
    "user_id": "2583717c-1d7a-4901-8788-a8096cfdf8e3",
    "start_on": "2026-10-01",
    "end_on": "2026-10-03",
    "status": "pending",
    "admin_comment": null,
    "requested_at": "2026-08-01T09:00:00.000Z"
  },
  {
    "id": "vac-unknown-user",
    "user_id": "00000000-0000-0000-0000-000000000000",
    "start_on": "2026-11-01",
    "end_on": "2026-11-02",
    "status": "pending",
    "admin_comment": null,
    "requested_at": "2026-08-02T09:00:00.000Z"
  }
]
''';

const cleaningJson = '''
{
  "lists": [
    {
      "id": "list-gara-closing",
      "location_id": "ff63f35a-ddd1-449e-9021-33ee78e2261a",
      "key": "closing"
    },
    {
      "id": "list-ag-closing",
      "location_id": "cc643d67-081b-44e1-b4c0-c0194fbb9aab",
      "key": "closing"
    },
    {
      "id": "list-gara-monday",
      "location_id": "ff63f35a-ddd1-449e-9021-33ee78e2261a",
      "key": "monday"
    }
  ],
  "tasks": [
    {
      "id": "task-gara-closing-0",
      "list_id": "list-gara-closing",
      "title": "Spalare LAF",
      "sort_order": 0,
      "is_active": true
    },
    {
      "id": "task-gara-closing-1",
      "list_id": "list-gara-closing",
      "title": "mop",
      "sort_order": 1,
      "is_active": true
    },
    {
      "id": "task-ag-closing-0",
      "list_id": "list-ag-closing",
      "title": "a da cu matura in depozit",
      "sort_order": 0,
      "is_active": true
    },
    {
      "id": "task-gara-monday-0",
      "list_id": "list-gara-monday",
      "title": "Monday task",
      "sort_order": 0,
      "is_active": true
    },
    {
      "id": "task-inactive",
      "list_id": "list-gara-closing",
      "title": "inactive",
      "sort_order": 9,
      "is_active": false
    }
  ],
  "completions": [
    {
      "id": "comp-1",
      "user_id": "cb3355e2-1bad-4826-8796-ca1734ce288a",
      "task_id": "task-gara-closing-0",
      "week_id": "2026-W32",
      "completed": true,
      "completed_at": "2026-08-13T21:10:43.362Z"
    },
    {
      "id": "comp-2",
      "user_id": "cb3355e2-1bad-4826-8796-ca1734ce288a",
      "task_id": "task-gara-closing-1",
      "week_id": "2026-W32",
      "completed": false,
      "completed_at": null
    },
    {
      "id": "comp-other-week",
      "user_id": "cb3355e2-1bad-4826-8796-ca1734ce288a",
      "task_id": "task-gara-closing-0",
      "week_id": "2026-W33",
      "completed": true,
      "completed_at": "2026-08-20T10:00:00.000Z"
    },
    {
      "id": "comp-unknown-user",
      "user_id": "00000000-0000-0000-0000-000000000000",
      "task_id": "task-gara-closing-0",
      "week_id": "2026-W32",
      "completed": true,
      "completed_at": "2026-08-13T21:10:43.362Z"
    }
  ]
}
''';

const consumptionsOneJson = '''
[
  {
    "id": "cons-1",
    "user_id": "cb3355e2-1bad-4826-8796-ca1734ce288a",
    "product_id": "prod-coffee",
    "location_id": "ff63f35a-ddd1-449e-9021-33ee78e2261a",
    "quantity": 2,
    "consumed_on": "2026-08-13",
    "logged_at": "2026-08-13T09:15:00.000Z",
    "notes": "after shift"
  },
  {
    "id": "cons-other-month",
    "user_id": "cb3355e2-1bad-4826-8796-ca1734ce288a",
    "product_id": "prod-coffee",
    "location_id": "ff63f35a-ddd1-449e-9021-33ee78e2261a",
    "quantity": 1,
    "consumed_on": "2026-07-01",
    "logged_at": "2026-07-01T09:15:00.000Z",
    "notes": null
  },
  {
    "id": "cons-unknown-user",
    "user_id": "00000000-0000-0000-0000-000000000000",
    "product_id": "prod-coffee",
    "location_id": "ff63f35a-ddd1-449e-9021-33ee78e2261a",
    "quantity": 1,
    "consumed_on": "2026-08-13",
    "logged_at": "2026-08-13T09:15:00.000Z",
    "notes": null
  }
]
''';

MockClient vccApiMock({
  String vacations = vacationsJson,
  String cleaning = cleaningJson,
  String consumptions = '[]',
  String products = productsJson,
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
        return http.Response(locationsJson, 200);
      case '/api/users':
        return http.Response(usersJson, 200);
      case '/api/products':
        return http.Response(products, 200);
      case '/api/vacations':
        return http.Response(vacations, 200);
      case '/api/cleaning':
        return http.Response(cleaning, 200);
      case '/api/consumptions':
        return http.Response(consumptions, 200);
      default:
        return http.Response('not found', 404);
    }
  });
}

class VccApiRepos {
  VccApiRepos(this.api)
      : locations = LocationRepository(apiClient: api),
        users = UsersRepository(
          apiClient: api,
          locationRepository: LocationRepository(apiClient: api),
        ),
        products = ProductRepository(apiClient: api);

  final ApiClient api;
  final LocationRepository locations;
  final UsersRepository users;
  final ProductRepository products;

  VacationRepository get vacations => VacationRepository(
        apiClient: api,
        usersRepository: users,
      );

  CleaningRepository get cleaning => CleaningRepository(
        apiClient: api,
        usersRepository: users,
        locationRepository: locations,
      );

  ConsumptionRepository get consumptions => ConsumptionRepository(
        apiClient: api,
        usersRepository: users,
        productRepository: products,
      );
}

VccApiRepos buildVccRepos(MockClient httpClient) {
  return VccApiRepos(buildTestApiClient(httpClient: httpClient));
}
