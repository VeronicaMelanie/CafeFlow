import 'package:flutter/material.dart';

import '../domain/availability_model.dart';
import '../domain/shift_type.dart';
import 'widgets/shift_type_selection_sheet.dart';

/// Local draft for one availability day before Save & Done.
class DayAvailabilityDraft {
  final AvailabilityShiftType shiftType;
  final TimeOfDay? customStart;
  final TimeOfDay? customEnd;
  final String? existingDocId;

  const DayAvailabilityDraft({
    required this.shiftType,
    this.customStart,
    this.customEnd,
    this.existingDocId,
  });

  factory DayAvailabilityDraft.fromModel(AvailabilityModel model) {
    return DayAvailabilityDraft(
      shiftType: model.shiftType,
      customStart: model.customStartTime != null
          ? TimeOfDay.fromDateTime(model.customStartTime!)
          : null,
      customEnd: model.customEndTime != null
          ? TimeOfDay.fromDateTime(model.customEndTime!)
          : null,
      existingDocId: model.id.isNotEmpty ? model.id : null,
    );
  }

  factory DayAvailabilityDraft.fromSelection(
    ShiftTypeSelectionResult selection, {
    String? existingDocId,
  }) {
    return DayAvailabilityDraft(
      shiftType: selection.shiftType,
      customStart: selection.start,
      customEnd: selection.end,
      existingDocId: existingDocId,
    );
  }

  ShiftTypeSelectionResult toSelectionResult() {
    return ShiftTypeSelectionResult(
      shiftType: shiftType,
      start: customStart,
      end: customEnd,
    );
  }

  DateTime? customStartDateTime(DateTime day) {
    if (shiftType != AvailabilityShiftType.customHours || customStart == null) {
      return null;
    }
    return DateTime(
      day.year,
      day.month,
      day.day,
      customStart!.hour,
      customStart!.minute,
    );
  }

  DateTime? customEndDateTime(DateTime day) {
    if (shiftType != AvailabilityShiftType.customHours || customEnd == null) {
      return null;
    }
    return DateTime(
      day.year,
      day.month,
      day.day,
      customEnd!.hour,
      customEnd!.minute,
    );
  }

  /// True when this draft differs from a persisted [AvailabilityModel].
  bool needsPersistComparedTo(AvailabilityModel? existing) {
    if (existing == null) return true;
    if (shiftType != existing.shiftType) return true;
    if (shiftType == AvailabilityShiftType.fullTime) return false;

    final existingStart = existing.customStartTime;
    final existingEnd = existing.customEndTime;
    final draftStart = customStartDateTime(existing.date);
    final draftEnd = customEndDateTime(existing.date);
    if (existingStart == null ||
        existingEnd == null ||
        draftStart == null ||
        draftEnd == null) {
      return true;
    }
    return existingStart.hour != draftStart.hour ||
        existingStart.minute != draftStart.minute ||
        existingEnd.hour != draftEnd.hour ||
        existingEnd.minute != draftEnd.minute;
  }

  DayAvailabilityDraft copyWith({
    AvailabilityShiftType? shiftType,
    TimeOfDay? customStart,
    TimeOfDay? customEnd,
    String? existingDocId,
  }) {
    return DayAvailabilityDraft(
      shiftType: shiftType ?? this.shiftType,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
      existingDocId: existingDocId ?? this.existingDocId,
    );
  }
}

DateTime normalizeAvailabilityDay(DateTime day) =>
    DateTime(day.year, day.month, day.day);

enum AvailabilityPersistKind { delete, create, update, skip }

class AvailabilityPersistAction {
  final AvailabilityPersistKind kind;
  final DateTime? day;
  final DayAvailabilityDraft? draft;
  final String? docId;

  const AvailabilityPersistAction._({
    required this.kind,
    this.day,
    this.draft,
    this.docId,
  });

  const AvailabilityPersistAction.delete(String docId)
      : this._(kind: AvailabilityPersistKind.delete, docId: docId);

  const AvailabilityPersistAction.create(DateTime day, DayAvailabilityDraft draft)
      : this._(kind: AvailabilityPersistKind.create, day: day, draft: draft);

  const AvailabilityPersistAction.update(DateTime day, DayAvailabilityDraft draft)
      : this._(kind: AvailabilityPersistKind.update, day: day, draft: draft);

  const AvailabilityPersistAction.skip(DateTime day)
      : this._(kind: AvailabilityPersistKind.skip, day: day);
}

List<AvailabilityPersistAction> planAvailabilityPersist({
  required Map<DateTime, DayAvailabilityDraft> drafts,
  required List<AvailabilityModel> existingEntries,
}) {
  final existingByDay = {
    for (final e in existingEntries) normalizeAvailabilityDay(e.date): e,
  };
  final actions = <AvailabilityPersistAction>[];

  for (final entry in existingEntries) {
    final day = normalizeAvailabilityDay(entry.date);
    if (!drafts.containsKey(day)) {
      actions.add(AvailabilityPersistAction.delete(entry.id));
    }
  }

  for (final entry in drafts.entries) {
    final day = entry.key;
    final draft = entry.value;
    final existing = existingByDay[day];

    if (existing == null) {
      actions.add(AvailabilityPersistAction.create(day, draft));
    } else if (draft.needsPersistComparedTo(existing)) {
      actions.add(AvailabilityPersistAction.update(day, draft));
    } else {
      actions.add(AvailabilityPersistAction.skip(day));
    }
  }

  return actions;
}
