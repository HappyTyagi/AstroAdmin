import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

class ChatPushService {
  final ApiClient _client = ApiClient();

  Future<void> sendChatNotificationToUser({
    required int recipientUserId,
    String? recipientMobileNo,
    required String senderName,
    required String messageType,
    required String content,
    String notificationType = 'SESSION',
    Map<String, dynamic>? actionData,
  }) async {
    final preview = _previewText(messageType, content);
    final actionJson = jsonEncode(actionData ?? <String, dynamic>{'source': 'chat'});
    try {
      if (recipientMobileNo != null && recipientMobileNo.trim().isNotEmpty) {
        await _client.post(
          '/notification/send-by-mobile',
          data: <String, dynamic>{
            'mobileNumber': recipientMobileNo,
            'title': senderName,
            'message': preview,
            'type': notificationType,
            'actionData': actionJson,
          },
        );
        return;
      }

      await _client.post(
        '/notification/send',
        data: <String, dynamic>{
          'userId': recipientUserId,
          'title': senderName,
          'message': preview,
          'type': notificationType,
          'actionData': actionJson,
        },
      );
    } catch (e) {
      debugPrint('[AdminPush] failed to send chat/call push: $e');
    }
  }

  String _previewText(String type, String content) {
    switch (type) {
      case 'image':
        return 'Sent a photo';
      case 'video':
        return 'Sent a video';
      case 'audio':
        return 'Sent an audio file';
      case 'file':
        return 'Sent a document';
      default:
        final String text = content.trim();
        if (text.isEmpty) return 'Sent a message';
        return text.length > 100 ? '${text.substring(0, 100)}...' : text;
    }
  }
}
