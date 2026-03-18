import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/support_call_screen.dart';
import 'admin_chat_service.dart';

class PushNotificationBootstrapService {
  static bool _initialized = false;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static final Set<String> _openedCallIds = <String>{};

  static bool _isChatPushForAdmin(Map<String, dynamic>? actionData) {
    if (actionData == null) return false;
    final String source = (actionData['source'] ?? '').toString().toLowerCase();
    final String chatId = (actionData['chatId'] ?? '').toString().trim();
    final String callId = (actionData['callId'] ?? '').toString().trim();
    final bool looksLikeChat =
        source == 'chat' ||
        (source.isEmpty && chatId.isNotEmpty && callId.isEmpty);
    if (!looksLikeChat) return false;
    final String targetRole = (actionData['targetRole'] ?? '')
        .toString()
        .toLowerCase();
    if (targetRole.isEmpty) return true;
    return targetRole == 'admin';
  }

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
    final String targetRole = (actionData['targetRole'] ?? '')
        .toString()
        .toLowerCase();

    if (source == 'call' && targetRole == 'admin') {
      await _openIncomingCall(message, actionData);
      return;
    }

    if (_isChatPushForAdmin(actionData)) {
      _ingestChatMessage(message, actionData);
      _navigatorKey?.currentState?.pushNamed('/home');
    }
  }

  static void _ingestChatMessage(
    RemoteMessage message,
    Map<String, dynamic> actionData,
  ) {
    final String chatId = (actionData['chatId'] ?? '').toString().trim();
    if (chatId.isEmpty) {
      return;
    }

    final String senderName =
        (actionData['senderName'] ??
                message.notification?.title ??
                message.data['title'] ??
                'User')
            .toString()
            .trim();
    final String content =
        (actionData['content'] ??
                message.notification?.body ??
                message.data['message'] ??
                'New message')
            .toString()
            .trim();
    final String id =
        (actionData['id'] ??
                actionData['messageId'] ??
                'push_${DateTime.now().microsecondsSinceEpoch}')
            .toString()
            .trim();
    final String timestamp = (actionData['timestamp'] ?? '').toString().trim();
    final int? senderId = int.tryParse(
      (actionData['senderId'] ?? '').toString().trim(),
    );
    final int? fileSize = int.tryParse(
      (actionData['fileSize'] ?? '').toString().trim(),
    );
    final int? mediaDuration = int.tryParse(
      (actionData['mediaDuration'] ?? '').toString().trim(),
    );

    AdminChatService().ingestPushMessage(<String, dynamic>{
      'id': id,
      'chatId': chatId,
      'senderId': senderId ?? 0,
      'senderName': senderName.isEmpty ? 'User' : senderName,
      'senderRole': (actionData['senderRole'] ?? 'user').toString().trim(),
      'messageType': (actionData['messageType'] ?? 'text').toString().trim(),
      'content': content.isEmpty ? 'New message' : content,
      'timestamp': timestamp.isEmpty
          ? DateTime.now().toIso8601String()
          : timestamp,
      if ((actionData['mediaUrl'] ?? '').toString().trim().isNotEmpty)
        'mediaUrl': (actionData['mediaUrl'] ?? '').toString().trim(),
      if ((actionData['fileName'] ?? '').toString().trim().isNotEmpty)
        'fileName': (actionData['fileName'] ?? '').toString().trim(),
      if ((fileSize ?? 0) > 0) 'fileSize': fileSize,
      if ((mediaDuration ?? 0) > 0) 'mediaDuration': mediaDuration,
      'isRead': false,
    });
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

    final RegExpMatch? chatMatch = RegExp(
      r'user_(\d+)_admin_\d+',
    ).firstMatch(chatId);
    final int remoteUserId = int.tryParse(chatMatch?.group(1) ?? '') ?? 0;
    if (remoteUserId <= 0) {
      return;
    }

    final String title = (message.notification?.title ?? '').trim();
    final String dataTitle = (message.data['title'] ?? '').toString().trim();
    final String callerName =
        ((actionData['callerName'] ?? '').toString().trim()).isNotEmpty
        ? (actionData['callerName'] ?? '').toString().trim()
        : (title.isNotEmpty
              ? title
              : (dataTitle.isNotEmpty ? dataTitle : 'User'));

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
      if ((data['id'] ?? '').toString().trim().isNotEmpty)
        'id': data['id'].toString().trim(),
      if ((data['senderId'] ?? '').toString().trim().isNotEmpty)
        'senderId': data['senderId'].toString().trim(),
      if ((data['senderName'] ?? '').toString().trim().isNotEmpty)
        'senderName': data['senderName'].toString().trim(),
      if ((data['senderRole'] ?? '').toString().trim().isNotEmpty)
        'senderRole': data['senderRole'].toString().trim(),
      if ((data['messageType'] ?? '').toString().trim().isNotEmpty)
        'messageType': data['messageType'].toString().trim(),
      if ((data['content'] ?? '').toString().trim().isNotEmpty)
        'content': data['content'].toString().trim(),
      if ((data['timestamp'] ?? '').toString().trim().isNotEmpty)
        'timestamp': data['timestamp'].toString().trim(),
      if ((data['mediaUrl'] ?? '').toString().trim().isNotEmpty)
        'mediaUrl': data['mediaUrl'].toString().trim(),
      if ((data['fileName'] ?? '').toString().trim().isNotEmpty)
        'fileName': data['fileName'].toString().trim(),
      if ((data['fileSize'] ?? '').toString().trim().isNotEmpty)
        'fileSize': data['fileSize'].toString().trim(),
      if ((data['mediaDuration'] ?? '').toString().trim().isNotEmpty)
        'mediaDuration': data['mediaDuration'].toString().trim(),
      if ((data['callerName'] ?? '').toString().trim().isNotEmpty)
        'callerName': data['callerName'].toString().trim(),
      if ((data['status'] ?? '').toString().trim().isNotEmpty)
        'status': data['status'].toString().trim(),
    };
  }
}
