import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fivetogo_scheduler/features/scheduling/domain/availability_model.dart';
import 'package:fivetogo_scheduler/features/scheduling/domain/shift_type.dart';
import 'package:fivetogo_scheduler/features/scheduling/presentation/availability_day_draft.dart';

void main() {
  final day = DateTime(2026, 9, 8);
  final customDay = DateTime(2026, 9, 9);

  group('DayAvailabilityDraft', () {
    test('fromModel restores Full Day', () {
      final model = AvailabilityModel(
        id: 'doc-full',
        userId: 'u1',
        date: day,
        shiftType: AvailabilityShiftType.fullTime,
      );

      final draft = DayAvailabilityDraft.fromModel(model);

      expect(draft.shiftType, AvailabilityShiftType.fullTime);
      expect(draft.customStart, isNull);
      expect(draft.customEnd, isNull);
      expect(draft.existingDocId, 'doc-full');
    });

    test('fromModel restores Custom Hours and times', () {
      final model = AvailabilityModel(
        id: 'doc-custom',
        userId: 'u1',
        date: customDay,
        shiftType: AvailabilityShiftType.customHours,
        customStartTime: DateTime(2026, 9, 9, 16, 0),
        customEndTime: DateTime(2026, 9, 9, 22, 0),
      );

      final draft = DayAvailabilityDraft.fromModel(model);

      expect(draft.shiftType, AvailabilityShiftType.customHours);
      expect(draft.customStart, const TimeOfDay(hour: 16, minute: 0));
      expect(draft.customEnd, const TimeOfDay(hour: 22, minute: 0));
      expect(draft.existingDocId, 'doc-custom');
    });

    test('needsPersistComparedTo returns false for unchanged Full Day', () {
      final model = AvailabilityModel(
        id: 'doc-full',
        userId: 'u1',
        date: day,
        shiftType: AvailabilityShiftType.fullTime,
      );
      final draft = DayAvailabilityDraft.fromModel(model);

      expect(draft.needsPersistComparedTo(model), isFalse);
    });

    test('needsPersistComparedTo returns true when Full Day becomes Custom', () {
      final model = AvailabilityModel(
        id: 'doc-full',
        userId: 'u1',
        date: day,
        shiftType: AvailabilityShiftType.fullTime,
      );
      final draft = DayAvailabilityDraft(
        shiftType: AvailabilityShiftType.customHours,
        customStart: const TimeOfDay(hour: 10, minute: 0),
        customEnd: const TimeOfDay(hour: 14, minute: 0),
        existingDocId: 'doc-full',
      );

      expect(draft.needsPersistComparedTo(model), isTrue);
    });

    test('needsPersistComparedTo detects custom time changes', () {
      final model = AvailabilityModel(
        id: 'doc-custom',
        userId: 'u1',
        date: customDay,
        shiftType: AvailabilityShiftType.customHours,
        customStartTime: DateTime(2026, 9, 9, 16, 0),
        customEndTime: DateTime(2026, 9, 9, 18, 0),
      );
      final draft = DayAvailabilityDraft(
        shiftType: AvailabilityShiftType.customHours,
        customStart: const TimeOfDay(hour: 16, minute: 0),
        customEnd: const TimeOfDay(hour: 22, minute: 0),
        existingDocId: 'doc-custom',
      );

      expect(draft.needsPersistComparedTo(model), isTrue);
    });
  });

  group('planAvailabilityPersist', () {
    test('creates for new days', () {
      final drafts = {
        day: const DayAvailabilityDraft(
          shiftType: AvailabilityShiftType.fullTime,
        ),
      };

      final actions = planAvailabilityPersist(
        drafts: drafts,
        existingEntries: const [],
      );

      expect(actions, hasLength(1));
      expect(actions.single.kind, AvailabilityPersistKind.create);
      expect(actions.single.day, day);
    });

    test('deletes removed days', () {
      final existing = AvailabilityModel(
        id: 'doc-removed',
        userId: 'u1',
        date: day,
        shiftType: AvailabilityShiftType.fullTime,
      );

      final actions = planAvailabilityPersist(
        drafts: {},
        existingEntries: [existing],
      );

      expect(actions, hasLength(1));
      expect(actions.single.kind, AvailabilityPersistKind.delete);
      expect(actions.single.docId, 'doc-removed');
    });

    test('updates changed existing days', () {
      final existing = AvailabilityModel(
        id: 'doc-update',
        userId: 'u1',
        date: day,
        shiftType: AvailabilityShiftType.fullTime,
      );
      final drafts = {
        day: const DayAvailabilityDraft(
          shiftType: AvailabilityShiftType.customHours,
          customStart: TimeOfDay(hour: 9, minute: 0),
          customEnd: TimeOfDay(hour: 12, minute: 0),
          existingDocId: 'doc-update',
        ),
      };

      final actions = planAvailabilityPersist(
        drafts: drafts,
        existingEntries: [existing],
      );

      expect(actions, hasLength(1));
      expect(actions.single.kind, AvailabilityPersistKind.update);
    });

    test('skips unchanged existing days', () {
      final existing = AvailabilityModel(
        id: 'doc-skip',
        userId: 'u1',
        date: day,
        shiftType: AvailabilityShiftType.fullTime,
      );
      final drafts = {
        day: DayAvailabilityDraft.fromModel(existing),
      };

      final actions = planAvailabilityPersist(
        drafts: drafts,
        existingEntries: [existing],
      );

      expect(actions, hasLength(1));
      expect(actions.single.kind, AvailabilityPersistKind.skip);
    });
  });
}
