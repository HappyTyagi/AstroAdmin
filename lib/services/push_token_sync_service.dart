import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class PushTokenSyncService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
        if (newToken.trim().isEmpty) return;
        await _syncToken(newToken.trim());
      });

      final token = await messaging.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _syncToken(token.trim());
      }
    } catch (e) {
      debugPrint('[PushSync][Admin] init failed: $e');
    }
  }

  static Future<void> syncNow() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;
      await _syncToken(token.trim());
    } catch (e) {
      debugPrint('[PushSync][Admin] syncNow failed: $e');
    }
  }

  static Future<void> _syncToken(String fcmToken) async {
    final prefs = await SharedPreferences.getInstance();
    final mobileNo = (prefs.getString('mobileNo') ?? '').trim();
    if (mobileNo.isEmpty) return;

    final normalized = mobileNo.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) return;

    try {
      await ApiClient().put(
        '/api/mobile/user/device/by-mobile/$normalized',
        queryParameters: <String, dynamic>{
          'deviceToken': 'admin_$normalized',
          'fcmToken': fcmToken,
          'appVersion': 'admin-1.0.0',
        },
      );
      debugPrint('[PushSync][Admin] token synced for $normalized');
    } catch (e) {
      debugPrint('[PushSync][Admin] token sync failed: $e');
    }
  }
}

