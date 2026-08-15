import 'package:fivetogo_scheduler/core/api/api_exception.dart';
import 'package:fivetogo_scheduler/features/locations/data/location_repository.dart';
import 'package:fivetogo_scheduler/features/locations/utils/location_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/api_test_harness.dart';

const _locationsJson = '''
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

void main() {
  test('maps GET /api/locations JSON to LocationModel id/code/name', () async {
    http.Request? captured;
    final repository = LocationRepository(
      apiClient: buildTestApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(_locationsJson, 200);
        }),
      ),
    );

    final locations = await repository.getLocations();

    expect(captured!.url.path, '/api/locations');
    expect(captured!.headers['Authorization'], 'Bearer firebase-id-token');
    expect(locations, hasLength(2));
    expect(locations[0].id, 'ff63f35a-ddd1-449e-9021-33ee78e2261a');
    expect(locations[0].code, 'gara');
    expect(locations[0].name, 'Gara');
    expect(locations[0].code, isNot(locations[0].name));
    expect(locations[1].code, 'avantgarden');
    expect(locations[1].name, 'Avantgarden');
    expect(
      LocationCatalog.names(locations),
      ['Gara', 'Avantgarden'],
    );
    expect(LocationCatalog.preferredName(locations), 'Gara');
    expect(LocationCatalog.byCode(locations, 'gara')?.name, 'Gara');
  });

  test('returns an empty list when the API has no locations', () async {
    final repository = LocationRepository(
      apiClient: buildTestApiClient(httpClient: jsonMock(200, '[]')),
    );

    final locations = await repository.getLocations();
    expect(locations, isEmpty);
    expect(LocationCatalog.preferredName(locations), 'Gara');
  });

  test('propagates HTTP errors', () async {
    final repository = LocationRepository(
      apiClient: buildTestApiClient(
        httpClient: jsonMock(500, '{"error":"internal_error"}'),
      ),
    );

    await expectLater(
      repository.getLocations(),
      throwsA(
        isA<ApiHttpException>().having((e) => e.statusCode, 'statusCode', 500),
      ),
    );
  });

  test('does not call the API when no user is signed in', () async {
    var calls = 0;
    final repository = LocationRepository(
      apiClient: buildTestApiClient(
        tokenSource: FakeTokenSource([null]),
        httpClient: MockClient((request) async {
          calls += 1;
          return http.Response('[]', 200);
        }),
      ),
    );

    await expectLater(
      repository.getLocations(),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
    expect(calls, 0);
  });
}
