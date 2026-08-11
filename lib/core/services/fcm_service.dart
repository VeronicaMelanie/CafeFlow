import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Persists the device FCM token on the signed-in user's Firestore profile.
class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> syncTokenForUser(String uid) async {
    if (kIsWeb) return;

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': token,
        });
      }

      _messaging.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': newToken,
        });
      });
    } catch (e) {
      debugPrint('FCM token sync failed: $e');
    }
  }
}
