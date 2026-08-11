import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/scheduling/domain/shift_model.dart';

/// Persists the last known schedule locally for offline viewing on web/PWA.
class ScheduleOfflineCache {
  static const _keyPrefix = 'offline_shifts_';

  Future<void> saveShifts(String userId, List<ShiftModel> shifts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = shifts.map(_shiftToJson).toList();
      await prefs.setString('$_keyPrefix$userId', jsonEncode(encoded));
      await prefs.setString(
        '$_keyPrefix${userId}_at',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('ScheduleOfflineCache.save failed: $e');
    }
  }

  Future<List<ShiftModel>> loadShifts(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_keyPrefix$userId');
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => _shiftFromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('ScheduleOfflineCache.load failed: $e');
      return [];
    }
  }

  Future<DateTime?> lastCachedAt(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final at = prefs.getString('$_keyPrefix${userId}_at');
    if (at == null) return null;
    return DateTime.tryParse(at);
  }

  Map<String, dynamic> _shiftToJson(ShiftModel s) => {
        'id': s.id,
        'userId': s.userId,
        'userName': s.userName,
        'date': s.date.toIso8601String(),
        'startTime': s.startTime.toIso8601String(),
        'endTime': s.endTime.toIso8601String(),
        'type': s.type,
        'location': s.location,
        'status': s.status,
      };

  ShiftModel _shiftFromJson(Map<String, dynamic> m) => ShiftModel(
        id: m['id'] as String? ?? '',
        userId: m['userId'] as String? ?? '',
        userName: m['userName'] as String? ?? '',
        date: DateTime.parse(m['date'] as String),
        startTime: DateTime.parse(m['startTime'] as String),
        endTime: DateTime.parse(m['endTime'] as String),
        type: m['type'] as String? ?? 'FULL',
        location: m['location'] as String? ?? 'Gara',
        status: m['status'] as String? ?? 'pending',
      );
}
