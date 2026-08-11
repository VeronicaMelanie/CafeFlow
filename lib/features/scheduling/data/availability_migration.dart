import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/shift_type.dart';

/// One-time migration for legacy availability documents (admin-only tooling).
class AvailabilityMigration {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Adds [shiftType] and [submissionTimestamp] to docs missing them.
  Future<int> migrateLegacyDocuments() async {
    final snap = await _firestore.collection('availability').get();
    var updated = 0;
    final batch = _firestore.batch();
    var ops = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      final needsShiftType = data['shiftType'] == null;
      final needsTimestamp = data['submissionTimestamp'] == null;
      if (!needsShiftType && !needsTimestamp) continue;

      final isFullDay = data['isFullDay'] as bool? ?? true;
      final patch = <String, dynamic>{};
      if (needsShiftType) {
        patch['shiftType'] = isFullDay
            ? AvailabilityShiftType.fullTime.firestoreValue
            : AvailabilityShiftType.customHours.firestoreValue;
      }
      if (needsTimestamp) {
        patch['submissionTimestamp'] =
            data['date'] ?? FieldValue.serverTimestamp();
      }
      batch.update(doc.reference, patch);
      updated++;
      ops++;
      if (ops >= 400) {
        await batch.commit();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
    return updated;
  }
}
