import 'package:fivetogo_scheduler/core/api/api_exception.dart';
import 'package:fivetogo_scheduler/features/products/data/product_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/api_test_harness.dart';

const _productsJson = '''
[
  {
    "id": "27ffe18d-22d5-4308-82bc-6e5f754b2f61",
    "name": "latte",
    "category_id": null,
    "sku": null,
    "is_active": true
  },
  {
    "id": "801141c0-b477-4a0d-9aa7-74665dac9151",
    "name": "espresso lung",
    "category_id": null,
    "sku": null,
    "is_active": true
  }
]
''';

void main() {
  test('maps GET /api/products JSON fields exactly', () async {
    http.Request? captured;
    final repository = ProductRepository(
      apiClient: buildTestApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(_productsJson, 200);
        }),
      ),
    );

    final products = await repository.getProducts();

    expect(captured!.url.path, '/api/products');
    expect(captured!.headers['Authorization'], 'Bearer firebase-id-token');
    expect(products, hasLength(2));
    expect(products[0].id, '27ffe18d-22d5-4308-82bc-6e5f754b2f61');
    expect(products[0].name, 'latte');
    expect(products[0].categoryId, isNull);
    expect(products[0].sku, isNull);
    expect(products[0].isActive, isTrue);
    expect(products[1].name, 'espresso lung');
  });

  test('returns an empty list when the API has no products', () async {
    final repository = ProductRepository(
      apiClient: buildTestApiClient(httpClient: jsonMock(200, '[]')),
    );

    expect(await repository.getProducts(), isEmpty);
  });

  test('propagates HTTP errors', () async {
    final repository = ProductRepository(
      apiClient: buildTestApiClient(
        httpClient: jsonMock(500, '{"error":"internal_error"}'),
      ),
    );

    await expectLater(
      repository.getProducts(),
      throwsA(
        isA<ApiHttpException>().having((e) => e.statusCode, 'statusCode', 500),
      ),
    );
  });

  test('does not call the API when no user is signed in', () async {
    var calls = 0;
    final repository = ProductRepository(
      apiClient: buildTestApiClient(
        tokenSource: FakeTokenSource([null]),
        httpClient: MockClient((request) async {
          calls += 1;
          return http.Response('[]', 200);
        }),
      ),
    );

    await expectLater(
      repository.getProducts(),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
    expect(calls, 0);
  });
}
