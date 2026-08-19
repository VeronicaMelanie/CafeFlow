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
      final productName =
          product?.name ?? map['product_name']?.toString().trim();
      if (user == null || productName == null || productName.isEmpty) continue;
      result.add(
        ConsumptionModel.fromApiJson(
          map,
          firebaseUid: user.uid,
          productName: productName,
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

  Future<void> addConsumption(
    ConsumptionModel consumption, {
    String? locationId,
  }) async {
    if (_testMode) return;
    final productName = consumption.productName.trim();
    if (productName.isEmpty) {
      throw const ApiException('Product name is required');
    }
    final productId = await _lookupProductId(productName);
    await _client.postJson(
      '/api/consumptions',
      body: {
        if (productId != null) 'product_id': productId,
        'product_name': productName,
        'consumed_on': ApiDateTime.formatDateOnly(consumption.date),
        'quantity': consumption.quantity,
        if (locationId != null && locationId.isNotEmpty) 'location_id': locationId,
        if (consumption.notes != null && consumption.notes!.trim().isNotEmpty)
          'notes': consumption.notes!.trim(),
      },
    );
    _products?.invalidateCache();
  }

  Future<void> updateConsumption(
    String id,
    String productName,
    int quantity,
    String notes,
  ) async {
    if (_testMode) return;
    final trimmedName = productName.trim();
    if (trimmedName.isEmpty) {
      throw const ApiException('Product name is required');
    }
    final productId = await _lookupProductId(trimmedName);
    await _client.patchJson(
      '/api/consumptions/$id',
      body: {
        if (productId != null) 'product_id': productId,
        'product_name': trimmedName,
        'quantity': quantity,
        'notes': notes.trim().isEmpty ? null : notes.trim(),
      },
    );
    _products?.invalidateCache();
  }

  Future<void> deleteConsumption(String id) async {
    if (_testMode) return;
    await _client.delete('/api/consumptions/$id');
  }

  Future<String?> _lookupProductId(String name) async {
    final needle = name.trim().toLowerCase();
    if (needle.isEmpty) return null;
    final products = await _productRepo.getProducts();
    ProductModel? exact;
    ProductModel? partial;
    var partialCount = 0;
    for (final product in products) {
      final productName = product.name.trim().toLowerCase();
      if (productName == needle) {
        exact = product;
        break;
      }
      if (product.isActive && productName.contains(needle)) {
        partialCount += 1;
        partial = product;
      }
    }
    final match = exact ?? (partialCount == 1 ? partial : null);
    final id = match?.id;
    if (id == null || !_looksLikeUuid(id)) return null;
    return id;
  }

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  bool _looksLikeUuid(String value) => _uuidPattern.hasMatch(value);
}

final consumptionRepositoryProvider = Provider(
  (ref) => ConsumptionRepository(
    apiClient: ref.watch(apiClientProvider),
    usersRepository: ref.watch(usersRepositoryProvider),
    productRepository: ref.watch(productRepositoryProvider),
  ),
);
