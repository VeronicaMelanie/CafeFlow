import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_datetime.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import '../../auth/data/users_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product_model.dart';
import '../../products/presentation/product_providers.dart';
import '../domain/consumption_model.dart';

class ConsumptionRepository {
  ConsumptionRepository({
    ApiClient? apiClient,
    UsersRepository? usersRepository,
    ProductRepository? productRepository,
    bool testMode = false,
  })  : _api = apiClient,
        _users = usersRepository,
        _products = productRepository,
        _testMode = testMode;

  @visibleForTesting
  ConsumptionRepository.test() : this(testMode: true);

  final ApiClient? _api;
  final UsersRepository? _users;
  final ProductRepository? _products;
  final bool _testMode;

  ApiClient get _client {
    final api = _api;
    if (api == null) {
      throw const ApiException('Consumptions API client is not configured');
    }
    return api;
  }

  ProductRepository get _productRepo {
    final products = _products;
    if (products == null) {
      throw const ApiException('Consumptions product repository is not configured');
    }
    return products;
  }

  /// GET /api/consumptions returns all rows (currently often empty).
  /// Filter user/month client-side. Do not invent rows when PostgreSQL is empty.
  Future<List<ConsumptionModel>> getAllConsumptionsUnfiltered() async {
    if (_testMode) return const [];
    final users = _users;
    if (users == null) {
      throw const ApiException('Consumptions API client is not configured');
    }

    final json = await _client.getJson('/api/consumptions');
    if (json is! List) {
      throw const ApiException('Expected a JSON array from /api/consumptions');
    }

    final usersByPostgresId = await users.byPostgresId();
    final productById = {
      for (final product in await _productRepo.getProducts()) product.id: product,
    };
    final result = <ConsumptionModel>[];
    for (final item in json) {
      final map = Map<String, dynamic>.from(item as Map);
      final user = usersByPostgresId[map['user_id']?.toString() ?? ''];
      final product = productById[map['product_id']?.toString() ?? ''];
      if (user == null || product == null) continue;
      result.add(
        ConsumptionModel.fromApiJson(
          map,
          firebaseUid: user.uid,
          productName: product.name,
        ),
      );
    }
    return result;
  }

  Stream<List<ConsumptionModel>> getUserConsumptions(
    String userId,
    DateTime month,
  ) {
    return Stream.fromFuture(_userConsumptionsForMonth(userId, month));
  }

  Future<List<ConsumptionModel>> _userConsumptionsForMonth(
    String userId,
    DateTime month,
  ) async {
    return (await getAllConsumptionsUnfiltered())
        .where(
          (item) =>
              item.userId == userId &&
              item.date.year == month.year &&
              item.date.month == month.month,
        )
        .toList();
  }

  Stream<List<ConsumptionModel>> getAllConsumptions(DateTime month) {
    return Stream.fromFuture(_consumptionsForMonth(month));
  }

  Future<List<ConsumptionModel>> _consumptionsForMonth(DateTime month) async {
    return (await getAllConsumptionsUnfiltered())
        .where(
          (item) =>
              item.date.year == month.year && item.date.month == month.month,
        )
        .toList();
  }

  Stream<List<ConsumptionModel>> getConsumptionsForUser(String userId) {
    return Stream.fromFuture(_consumptionsForUser(userId));
  }

  Future<List<ConsumptionModel>> _consumptionsForUser(String userId) async {
    final items = (await getAllConsumptionsUnfiltered())
        .where((item) => item.userId == userId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  Future<void> addConsumption(ConsumptionModel consumption) async {
    if (_testMode) return;
    final productId = await _productIdForName(consumption.productName);
    await _client.postJson(
      '/api/consumptions',
      body: {
        'product_id': productId,
        'consumed_on': ApiDateTime.formatDateOnly(consumption.date),
        'quantity': consumption.quantity,
        if (consumption.notes != null && consumption.notes!.trim().isNotEmpty)
          'notes': consumption.notes!.trim(),
      },
    );
  }

  Future<void> updateConsumption(
    String id,
    String productName,
    int quantity,
    String notes,
  ) async {
    if (_testMode) return;
    final productId = await _productIdForName(productName);
    await _client.patchJson(
      '/api/consumptions/$id',
      body: {
        'product_id': productId,
        'quantity': quantity,
        'notes': notes.trim().isEmpty ? null : notes.trim(),
      },
    );
  }

  Future<void> deleteConsumption(String id) async {
    if (_testMode) return;
    await _client.delete('/api/consumptions/$id');
  }

  Future<String> _productIdForName(String name) async {
    final products = await _productRepo.getProducts();
    ProductModel? match;
    for (final product in products) {
      if (product.name == name) {
        match = product;
        break;
      }
    }
    if (match == null) {
      throw ApiException('Unknown product: $name');
    }
    return match.id;
  }
}

final consumptionRepositoryProvider = Provider(
  (ref) => ConsumptionRepository(
    apiClient: ref.watch(apiClientProvider),
    usersRepository: ref.watch(usersRepositoryProvider),
    productRepository: ref.watch(productRepositoryProvider),
  ),
);
