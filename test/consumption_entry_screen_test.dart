import 'dart:async';

import 'package:fivetogo_scheduler/features/auth/domain/user_model.dart';
import 'package:fivetogo_scheduler/features/auth/presentation/auth_providers.dart';
import 'package:fivetogo_scheduler/features/consumption/data/consumption_repository.dart';
import 'package:fivetogo_scheduler/features/consumption/domain/consumption_model.dart';
import 'package:fivetogo_scheduler/features/consumption/presentation/consumption_entry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class TestConsumptionRepository extends ConsumptionRepository {
  TestConsumptionRepository() : super.test();

  final List<ConsumptionModel> items = [];
  bool failOnAdd = false;
  final StreamController<List<ConsumptionModel>> _controller =
      StreamController<List<ConsumptionModel>>.broadcast();

  void _emit() => _controller.add(List.unmodifiable(items));

  @override
  Future<void> addConsumption(ConsumptionModel consumption) async {
    if (failOnAdd) {
      throw Exception('save failed');
    }
    items.insert(
      0,
      ConsumptionModel(
        id: 'test-${items.length}',
        userId: consumption.userId,
        productName: consumption.productName,
        quantity: consumption.quantity,
        date: consumption.date,
        notes: consumption.notes,
      ),
    );
    _emit();
  }

  @override
  Stream<List<ConsumptionModel>> getConsumptionsForUser(String userId) {
    return Stream<List<ConsumptionModel>>.multi((controller) {
      void emitNow() {
        if (!controller.isClosed) {
          controller.add(items.where((c) => c.userId == userId).toList());
        }
      }

      emitNow();
      final sub = _controller.stream.listen((_) => emitNow());
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<void> updateConsumption(
    String id,
    String productName,
    int quantity,
    String notes,
  ) async {}

  @override
  Future<void> deleteConsumption(String id) async {}
}

void main() {
  final testUser = UserModel(
    uid: 'user-1',
    email: 'test@example.com',
    name: 'Test User',
    role: 'employee',
    workType: 'Full-time',
    monthlyTargetHours: 160,
    primaryLocation: 'Gara',
    secondaryLocation: 'Avantgarden',
  );

  late TestConsumptionRepository repository;

  Widget buildTestApp() {
    repository = TestConsumptionRepository();
    return ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) async => testUser),
        consumptionRepositoryProvider.overrideWith((ref) => repository),
      ],
      child: const MaterialApp(home: ConsumptionEntryScreen()),
    );
  }

  Future<void> enterProduct(WidgetTester tester, String product) async {
    await tester.enterText(find.byType(TextFormField), product);
    await tester.pump();
  }

  Future<void> submitConsumption(WidgetTester tester) async {
    await tester.tap(find.text('Add to My Log'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> settleScreen(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> prepareScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildTestApp());
    await settleScreen(tester);
  }

  testWidgets('clears product field after successful save', (tester) async {
    await prepareScreen(tester);

    await enterProduct(tester, 'espresso lung');
    await submitConsumption(tester);

    expect(find.text('Logged! Enjoy your coffee! ☕'), findsOneWidget);

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, isEmpty);
    expect(find.text('espresso lung'), findsOneWidget);
  });

  testWidgets('allows logging a second product without manual clear',
      (tester) async {
    await prepareScreen(tester);

    await enterProduct(tester, 'espresso lung');
    await submitConsumption(tester);

    await enterProduct(tester, 'cappuccino');
    await submitConsumption(tester);

    expect(find.text('Logged! Enjoy your coffee! ☕'), findsOneWidget);
    expect(repository.items, hasLength(2));
    expect(repository.items[0].productName, 'cappuccino');
    expect(repository.items[1].productName, 'espresso lung');

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('preserves product input when save fails', (tester) async {
    await prepareScreen(tester);

    repository.failOnAdd = true;
    await enterProduct(tester, 'espresso lung');
    await submitConsumption(tester);

    expect(find.text('Could not save: Exception: save failed'), findsOneWidget);
    expect(find.text('espresso lung'), findsOneWidget);

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, 'espresso lung');
  });
}
