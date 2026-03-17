import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/support_call_screen.dart';

class PushNotificationBootstrapService {
  static bool _initialized = false;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static final Set<String> _openedCallIds = <String>{};

  static Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;
    if (_initialized) {
      return;
    }
    _initialized = true;

    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _handleMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await _handleMessage(message);
    });

    final RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleMessage(initialMessage);
    }
  }

  static Future<void> handleBackgroundPush(RemoteMessage message) async {
    debugPrint('[AdminPush] background push received: ${message.messageId}');
  }

  static Future<void> _handleMessage(RemoteMessage message) async {
    final Map<String, dynamic>? actionData = _extractActionData(message.data);
    if (actionData == null) {
      return;
    }

    final String source = (actionData['source'] ?? '').toString().toLowerCase();
    final String targetRole =
        (actionData['targetRole'] ?? '').toString().toLowerCase();

    if (source == 'call' && targetRole == 'admin') {
      await _openIncomingCall(message, actionData);
      return;
    }

    if (source == 'chat' && targetRole == 'admin') {
      _navigatorKey?.currentState?.pushNamed('/home');
    }
  }

  static Future<void> _openIncomingCall(
    RemoteMessage message,
    Map<String, dynamic> actionData,
  ) async {
    final String chatId = (actionData['chatId'] ?? '').toString().trim();
    final String callId = (actionData['callId'] ?? '').toString().trim();
    final String callType =
        (actionData['callType'] ?? '').toString().toLowerCase() == 'video'
            ? 'video'
            : 'audio';
    final String status = (actionData['status'] ?? '').toString().toLowerCase();

    if (chatId.isEmpty || callId.isEmpty) {
      return;
    }
    if (status == 'ended' || status == 'rejected' || status == 'missed') {
      _openedCallIds.remove(callId);
      return;
    }
    if (_openedCallIds.contains(callId)) {
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int localUserId = prefs.getInt('userId') ?? 0;
    if (localUserId <= 0) {
      return;
    }

    final RegExpMatch? chatMatch = RegExp(r'user_(\d+)_admin_\d+').firstMatch(chatId);
    final int remoteUserId =
        int.tryParse(chatMatch?.group(1) ?? '') ?? 0;
    if (remoteUserId <= 0) {
      return;
    }

    final String title = (message.notification?.title ?? '').trim();
    final String dataTitle = (message.data['title'] ?? '').toString().trim();
    final String callerName = ((actionData['callerName'] ?? '').toString().trim())
            .isNotEmpty
        ? (actionData['callerName'] ?? '').toString().trim()
        : (title.isNotEmpty ? title : (dataTitle.isNotEmpty ? dataTitle : 'User'));

    final NavigatorState? navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      return;
    }

    _openedCallIds.add(callId);
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => SupportCallScreen(
          chatId: chatId,
          callId: callId,
          callType: callType,
          localUserId: localUserId,
          remoteUserId: remoteUserId,
          participantName: callerName,
          acceptOnOpen: true,
        ),
      ),
    );
    _openedCallIds.remove(callId);
  }

  static Map<String, dynamic>? _extractActionData(Map<String, dynamic> data) {
    final dynamic raw = data['actionData'];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    final String source = (data['source'] ?? '').toString().trim();
    final String chatId = (data['chatId'] ?? '').toString().trim();
    final String callId = (data['callId'] ?? '').toString().trim();
    if (source.isEmpty && chatId.isEmpty && callId.isEmpty) {
      return null;
    }
    return <String, dynamic>{
      if (source.isNotEmpty) 'source': source,
      if (chatId.isNotEmpty) 'chatId': chatId,
      if (callId.isNotEmpty) 'callId': callId,
      if ((data['callType'] ?? '').toString().trim().isNotEmpty)
        'callType': data['callType'].toString().trim(),
      if ((data['targetRole'] ?? '').toString().trim().isNotEmpty)
        'targetRole': data['targetRole'].toString().trim(),
      if ((data['callerName'] ?? '').toString().trim().isNotEmpty)
        'callerName': data['callerName'].toString().trim(),
      if ((data['status'] ?? '').toString().trim().isNotEmpty)
        'status': data['status'].toString().trim(),
    };
  }
}
