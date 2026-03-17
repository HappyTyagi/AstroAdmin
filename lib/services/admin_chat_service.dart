import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:agora_rtm/agora_rtm.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/admin_chat_model.dart';
import 'admin_chat_local_db.dart';
import 'api_client.dart';
import 'api_config.dart';

class AdminChatService {
  static const int adminUserId = 1;
  static const Duration _chatListPollInterval = Duration(seconds: 4);

  final ApiClient _client = ApiClient();
  final Map<String, StreamController<List<AdminMessage>>> _messageControllers =
      <String, StreamController<List<AdminMessage>>>{};
  final Map<String, List<AdminMessage>> _messageCache =
      <String, List<AdminMessage>>{};
  final Map<String, bool> _channelSubscriptions = <String, bool>{};
  final Map<String, Future<void>> _historyLoads = <String, Future<void>>{};
  final Random _random = Random();
  final AdminChatLocalDb _localDb = AdminChatLocalDb();

  RtmClient? _rtmClient;
  String? _rtmUserId;
  Future<void>? _rtmInitFuture;
  bool _listenerAttached = false;

  String _channelNameForChatId(String chatId) {
    final match = RegExp(r'user_(\d+)_admin_\d+').firstMatch(chatId);
    if (match != null) {
      return 'admin_support_${match.group(1)}';
    }
    return chatId;
  }

  Future<Map<String, dynamic>> _readAuthContext() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int userId = prefs.getInt('userId') ?? 0;
    final String role = (prefs.getString('role') ?? 'USER')
        .trim()
        .toUpperCase();
    final String name = (prefs.getString('name') ?? '').trim();
    final String mobileNo = (prefs.getString('mobileNo') ?? '').trim();
    final String avatar = (prefs.getString('profileImageUrl') ?? '').trim();
    if (userId <= 0) {
      throw Exception('User session not found');
    }
    return <String, dynamic>{
      'userId': userId,
      'role': role,
      'name': name,
      'mobileNo': mobileNo,
      'avatar': avatar,
    };
  }

  String _buildDesiredRtmUserId(Map<String, dynamic> context) {
    final int userId = context['userId'] as int;
    final String role = (context['role'] as String?) ?? 'USER';
    return role == 'ADMIN' ? 'admin_$userId' : 'user_$userId';
  }

  Future<void> _ensureRtmReady() async {
    final Map<String, dynamic> context = await _readAuthContext();
    final String desiredRtmUserId = _buildDesiredRtmUserId(context);

    if (_rtmClient != null && _rtmUserId == desiredRtmUserId) {
      return;
    }

    if (_rtmInitFuture != null) {
      await _rtmInitFuture;
      if (_rtmClient != null && _rtmUserId == desiredRtmUserId) {
        return;
      }
    }

    _rtmInitFuture = _initializeRtmClient(desiredRtmUserId);
    try {
      await _rtmInitFuture;
    } finally {
      _rtmInitFuture = null;
    }
  }

  bool _isRecoverableRtmReason(String reason) {
    final normalized = reason.toLowerCase();
    return normalized.contains('not connected') ||
        normalized.contains('authorized') ||
        normalized.contains('token') ||
        normalized.contains('connection') ||
        normalized.contains('logout');
  }

  bool _isRtmServiceUnavailableReason(String reason) {
    final normalized = reason.toLowerCase();
    return (normalized.contains('rtm') && normalized.contains('not enable')) ||
        (normalized.contains('rtm') && normalized.contains('not enabled')) ||
        normalized.contains('not enaable') ||
        (normalized.contains('service') &&
            normalized.contains('has been stop')) ||
        (normalized.contains('service') && normalized.contains('stopped'));
  }

  bool _isRtmUnavailableError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('agora rtm unavailable') ||
        message.contains('rtm unavailable') ||
        message.contains('not enaable') ||
        message.contains('not enable') ||
        message.contains('not enabled') ||
        message.contains('has been stop') ||
        message.contains('stopped');
  }

  Future<void> _resetRtmState() async {
    final RtmClient? client = _rtmClient;
    _rtmClient = null;
    _rtmUserId = null;
    _listenerAttached = false;
    _channelSubscriptions.clear();
    _historyLoads.clear();
    if (client != null) {
      try {
        await client.release();
      } catch (_) {}
    }
  }

  Future<void> _initializeRtmClient(String desiredRtmUserId) async {
    final Response<dynamic> response = await _client.get(
      ApiConfig.adminSupportRtmToken,
    );
    final Map<String, dynamic> data = Map<String, dynamic>.from(
      response.data as Map,
    );
    final String appId = (data['appId'] ?? '').toString().trim();
    final String token = (data['token'] ?? '').toString();
    final String rtmUserId = (data['rtmUserId'] ?? desiredRtmUserId)
        .toString()
        .trim();

    if (appId.isEmpty) {
      throw Exception(data['message'] ?? 'Agora RTM App ID is missing');
    }

    if (_rtmClient != null) {
      await _resetRtmState();
    }

    final (RtmStatus status, RtmClient client) = await RTM(
      appId,
      rtmUserId,
      config: const RtmConfig(useStringUserId: true, reconnectTimeout: 10),
    );
    if (status.error) {
      throw Exception('Agora RTM init failed: ${status.reason}');
    }

    _rtmClient = client;
    _rtmUserId = rtmUserId;

    if (!_listenerAttached) {
      _rtmClient!.addListener(
        message: _handleIncomingMessage,
        token: (TokenEvent event) {
          debugPrint('[AdminChat][RTM] Token event: ${event.toJson()}');
        },
        linkState: (LinkStateEvent event) {
          debugPrint('[AdminChat][RTM] Link state: ${event.toJson()}');
          final reason = (event.reason ?? '').trim();
          if (_isRecoverableRtmReason(reason)) {
            Future<void>.microtask(_resetRtmState);
          }
        },
      );
      _listenerAttached = true;
    }

    final (RtmStatus loginStatus, _) = await _rtmClient!.login(token);
    if (loginStatus.error) {
      if (_isRtmServiceUnavailableReason(loginStatus.reason)) {
        await _resetRtmState();
        debugPrint(
          '[AdminChat][RTM] login unavailable, switching to limited mode: ${loginStatus.reason}',
        );
        return;
      }
      throw Exception('Agora RTM login failed: ${loginStatus.reason}');
    }
  }

  void _handleIncomingMessage(MessageEvent event) {
    final Uint8List? bytes = event.message;
    if (bytes == null || bytes.isEmpty) {
      return;
    }
    final String raw = utf8.decode(bytes, allowMalformed: true).trim();
    if (raw.isEmpty) {
      return;
    }
    final Map<String, dynamic> data = _parseJsonMap(raw);
    if (data.isEmpty) {
      return;
    }
    final AdminMessage message = _messageFromPayload(
      data,
      fallbackTimestamp: event.timestamp,
    );
    if (message.chatId.isEmpty) {
      return;
    }
    _mergeMessage(message.chatId, message);
  }

  AdminMessage _messageFromPayload(
    Map<String, dynamic> data, {
    int? fallbackTimestamp,
  }) {
    final dynamic timestampRaw = data['timestamp'];
    String timestampString;
    if (timestampRaw is String && timestampRaw.trim().isNotEmpty) {
      timestampString = timestampRaw.trim();
    } else if (timestampRaw is num) {
      timestampString = DateTime.fromMillisecondsSinceEpoch(
        timestampRaw.toInt(),
      ).toIso8601String();
    } else if (fallbackTimestamp != null && fallbackTimestamp > 0) {
      timestampString = DateTime.fromMillisecondsSinceEpoch(
        fallbackTimestamp,
      ).toIso8601String();
    } else {
      timestampString = DateTime.now().toIso8601String();
    }

    return AdminMessage.fromJson(<String, dynamic>{
      ...data,
      'timestamp': timestampString,
      'id': (data['id'] ?? _generateMessageId()).toString(),
    });
  }

  void _mergeMessage(String chatId, AdminMessage message) {
    final List<AdminMessage> merged = _mergeUniqueMessages(
      _messageCache[chatId] ?? <AdminMessage>[],
      <AdminMessage>[message],
    );
    _messageCache[chatId] = merged;
    _messageControllers[chatId]?.add(List<AdminMessage>.unmodifiable(merged));
    _persistMessagesLocally(chatId, <AdminMessage>[message]);
  }

  Future<void> _loadLocalMessages(String chatId) async {
    try {
      final List<AdminMessage> localMessages = await _localDb.getMessages(
        chatId,
      );
      if (localMessages.isEmpty) {
        return;
      }
      final List<AdminMessage> merged = _mergeUniqueMessages(
        _messageCache[chatId] ?? <AdminMessage>[],
        localMessages,
      );
      _messageCache[chatId] = merged;
      _messageControllers[chatId]?.add(List<AdminMessage>.unmodifiable(merged));
    } catch (error) {
      debugPrint('[AdminChat][LocalDB] load failed for $chatId: $error');
    }
  }

  void _persistMessagesLocally(String chatId, List<AdminMessage> messages) {
    if (messages.isEmpty) {
      return;
    }
    Future<void>.microtask(() async {
      try {
        await _localDb.upsertMessages(chatId, messages);
      } catch (error) {
        debugPrint('[AdminChat][LocalDB] persist failed for $chatId: $error');
      }
    });
  }

  List<AdminMessage> _mergeUniqueMessages(
    List<AdminMessage> existing,
    List<AdminMessage> incoming,
  ) {
    final Map<String, AdminMessage> byKey = <String, AdminMessage>{};

    void put(AdminMessage message) {
      final String id = message.id.trim();
      final String key = id.isNotEmpty ? 'id:$id' : _messageSignature(message);
      final AdminMessage? previous = byKey[key];
      if (previous == null) {
        byKey[key] = message;
        return;
      }
      if (previous.isRead && !message.isRead) {
        byKey[key] = AdminMessage.fromJson(<String, dynamic>{
          ...message.toJson(),
          'isRead': true,
        });
      } else {
        byKey[key] = message;
      }
    }

    for (final AdminMessage message in existing) {
      put(message);
    }
    for (final AdminMessage message in incoming) {
      put(message);
    }

    final List<AdminMessage> merged = byKey.values.toList();
    merged.sort((AdminMessage a, AdminMessage b) {
      final int byTime = a.timestamp.compareTo(b.timestamp);
      if (byTime != 0) {
        return byTime;
      }
      return a.id.compareTo(b.id);
    });
    return merged;
  }

  String _messageSignature(AdminMessage message) {
    return '${message.senderRole}|${message.senderId}|${message.messageType}|${message.content.trim()}|${message.timestamp.millisecondsSinceEpoch}';
  }

  String _generateMessageId() {
    final int timestamp = DateTime.now().microsecondsSinceEpoch;
    final int random = _random.nextInt(1 << 32);
    return 'msg_${timestamp}_$random';
  }

  Map<String, dynamic> _parseJsonMap(String raw) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<void> _ensureSubscribed(String chatId) async {
    await _ensureRtmReady();
    if (_rtmClient == null) {
      throw Exception('Agora RTM unavailable for chat subscribe');
    }
    final String channelName = _channelNameForChatId(chatId);
    if (_channelSubscriptions[channelName] == true) {
      return;
    }
    for (int attempt = 0; attempt < 2; attempt++) {
      final (RtmStatus status, _) = await _rtmClient!.subscribe(
        channelName,
        withMessage: true,
        withMetadata: false,
        withPresence: false,
        withLock: false,
        beQuiet: false,
      );
      if (!status.error) {
        _channelSubscriptions[channelName] = true;
        return;
      }
      final String reason = status.reason;
      if (attempt == 0 && _isRecoverableRtmReason(reason)) {
        await _resetRtmState();
        await _ensureRtmReady();
        continue;
      }
      throw Exception('Failed to subscribe chat channel: ${status.reason}');
    }
  }

  Future<void> _loadHistory(String chatId) async {
    final String channelName = _channelNameForChatId(chatId);
    _historyLoads[chatId] ??= () async {
      try {
        await _ensureSubscribed(chatId);
      } catch (error) {
        if (_isRtmUnavailableError(error)) {
          _applyHistory(chatId, <HistoryMessage>[]);
          return;
        }
        rethrow;
      }
      if (_rtmClient == null) {
        _applyHistory(chatId, <HistoryMessage>[]);
        return;
      }
      final (RtmStatus status, result) = await _rtmClient!
          .getHistory()
          .getMessages(channelName, RtmChannelType.message, messageCount: 200);
      if (status.error) {
        if (_isRecoverableRtmReason(status.reason)) {
          await _resetRtmState();
          try {
            await _ensureSubscribed(chatId);
          } catch (error) {
            if (_isRtmUnavailableError(error)) {
              _applyHistory(chatId, <HistoryMessage>[]);
              return;
            }
            rethrow;
          }
          if (_rtmClient == null) {
            _applyHistory(chatId, <HistoryMessage>[]);
            return;
          }
          final (RtmStatus retryStatus, retryResult) = await _rtmClient!
              .getHistory()
              .getMessages(
                channelName,
                RtmChannelType.message,
                messageCount: 200,
              );
          if (retryStatus.error) {
            throw Exception(
              'Failed to load chat history: ${retryStatus.reason}',
            );
          }
          _applyHistory(chatId, retryResult?.messageList ?? <HistoryMessage>[]);
          return;
        }
        throw Exception('Failed to load chat history: ${status.reason}');
      }
      _applyHistory(chatId, result?.messageList ?? <HistoryMessage>[]);
    }();

    try {
      await _historyLoads[chatId];
    } finally {
      _historyLoads.remove(chatId);
    }
  }

  void _applyHistory(String chatId, List<HistoryMessage> history) {
    final List<AdminMessage> historyMessages = history
        .map((HistoryMessage entry) {
          final String raw = utf8.decode(
            entry.message ?? Uint8List(0),
            allowMalformed: true,
          );
          return _messageFromPayload(
            _parseJsonMap(raw),
            fallbackTimestamp: entry.timestamp,
          );
        })
        .where((AdminMessage item) => item.chatId == chatId)
        .toList();
    final List<AdminMessage> merged = _mergeUniqueMessages(
      _messageCache[chatId] ?? <AdminMessage>[],
      historyMessages,
    );
    _messageCache[chatId] = merged;
    _messageControllers[chatId]?.add(List<AdminMessage>.unmodifiable(merged));
    _persistMessagesLocally(chatId, merged);
  }

  Stream<List<AdminChatSession>> getAllChatsForAdmin() async* {
    while (true) {
      final List<AdminChatSession> chats = await _fetchAdminChats();
      yield chats;
      await Future<void>.delayed(_chatListPollInterval);
    }
  }

  Future<List<AdminChatSession>> _fetchAdminChats() async {
    final Response<dynamic> response = await _client.get(
      ApiConfig.adminSupportAdminSessions,
    );
    final Map<String, dynamic> data = Map<String, dynamic>.from(
      response.data as Map,
    );
    final List<dynamic> items =
        data['sessions'] as List<dynamic>? ?? <dynamic>[];
    return items
        .map(
          (dynamic item) =>
              AdminChatSession.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Stream<List<AdminMessage>> getMessagesStream(String chatId) {
    final StreamController<List<AdminMessage>> controller = _messageControllers
        .putIfAbsent(
          chatId,
          () => StreamController<List<AdminMessage>>.broadcast(),
        );
    if (_messageCache.containsKey(chatId)) {
      scheduleMicrotask(() {
        if (!controller.isClosed) {
          controller.add(
            List<AdminMessage>.unmodifiable(_messageCache[chatId]!),
          );
        }
      });
    } else {
      scheduleMicrotask(() async {
        await _loadLocalMessages(chatId);
        try {
          await _loadHistory(chatId);
        } catch (error) {
          if (_isRtmUnavailableError(error)) {
            if (!_messageCache.containsKey(chatId)) {
              _messageCache[chatId] = <AdminMessage>[];
            }
            if (!controller.isClosed && _messageCache.containsKey(chatId)) {
              controller.add(
                List<AdminMessage>.unmodifiable(_messageCache[chatId]!),
              );
            }
            return;
          }
          if (!controller.isClosed) {
            controller.addError(error);
          }
        }
      });
    }
    return controller.stream;
  }

  Future<AdminMessage> sendMessage({
    required String chatId,
    required int senderId,
    required String senderName,
    required String senderRole,
    required String messageType,
    required String content,
    String? senderAvatar,
    String? mediaUrl,
    String? fileName,
    int? fileSize,
    int? mediaDuration,
  }) async {
    var publishViaRtm = true;
    try {
      await _ensureSubscribed(chatId);
    } catch (error) {
      if (_isRtmUnavailableError(error)) {
        publishViaRtm = false;
        debugPrint(
          '[AdminChat] sendMessage fallback (RTM unavailable): $error',
        );
      } else {
        rethrow;
      }
    }

    final AdminMessage message = AdminMessage(
      id: _generateMessageId(),
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      senderAvatar: senderAvatar,
      messageType: messageType,
      content: content,
      mediaUrl: mediaUrl,
      fileName: fileName,
      fileSize: fileSize,
      mediaDuration: mediaDuration,
      timestamp: DateTime.now(),
      isRead: false,
    );

    if (!publishViaRtm || _rtmClient == null) {
      await _registerMessageActivity(chatId, message);
      _mergeMessage(chatId, message);
      return message;
    }

    final String channelName = _channelNameForChatId(chatId);
    for (int attempt = 0; attempt < 2; attempt++) {
      final (RtmStatus status, _) = await _rtmClient!.publish(
        channelName,
        jsonEncode(message.toJson()),
        channelType: RtmChannelType.message,
        customType: messageType,
        storeInHistory: true,
      );
      if (!status.error) {
        await _registerMessageActivity(chatId, message);
        _mergeMessage(chatId, message);
        return message;
      }
      final String reason = status.reason;
      if (attempt == 0 && _isRecoverableRtmReason(reason)) {
        await _resetRtmState();
        await _ensureSubscribed(chatId);
        continue;
      }
      throw Exception('Failed to send message: ${status.reason}');
    }
    throw Exception('Failed to send message');
  }

  Future<void> _registerMessageActivity(
    String chatId,
    AdminMessage message,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _client.post(
      '${ApiConfig.adminSupportSessions}/$chatId/message-activity',
      data: <String, dynamic>{
        'senderRole': message.senderRole,
        'messageType': message.messageType,
        'preview': message.content,
        'userName': prefs.getString('name'),
        'userPhone': prefs.getString('mobileNo'),
        'userAvatar': prefs.getString('profileImageUrl'),
      },
    );
  }

  Future<void> sendTextMessage({
    required String chatId,
    required String content,
    required String senderName,
    int? senderId,
  }) async {
    await sendMessage(
      chatId: chatId,
      senderId: senderId ?? adminUserId,
      senderName: senderName,
      senderRole: 'admin',
      messageType: 'text',
      content: content,
    );
  }

  Future<void> markMessagesAsRead(String chatId) async {
    await _client.post(
      '${ApiConfig.adminSupportSessions}/$chatId/read',
      data: <String, dynamic>{'role': 'admin'},
    );
    final List<AdminMessage> current = List<AdminMessage>.from(
      _messageCache[chatId] ?? <AdminMessage>[],
    );
    final List<AdminMessage> updated = current.map((AdminMessage message) {
      if (message.senderRole != 'user') {
        return message;
      }
      return AdminMessage.fromJson(<String, dynamic>{
        ...message.toJson(),
        'isRead': true,
      });
    }).toList();
    _messageCache[chatId] = updated;
    _messageControllers[chatId]?.add(List<AdminMessage>.unmodifiable(updated));
    _persistMessagesLocally(chatId, updated);
  }

  Future<AdminChatSession> getChatSession(String chatId) async {
    final Response<dynamic> response = await _client.get(
      '${ApiConfig.adminSupportSessions}/$chatId',
    );
    final Map<String, dynamic> data = Map<String, dynamic>.from(
      response.data as Map,
    );
    final Map<String, dynamic> session = Map<String, dynamic>.from(
      data['session'] as Map? ?? <String, dynamic>{},
    );
    return AdminChatSession.fromJson(session);
  }

  Future<AdminCallSession> startCall({
    required String chatId,
    required String initiatorName,
    required String callType,
  }) async {
    final Response<dynamic> response = await _client.post(
      '${ApiConfig.adminSupportSessions}/$chatId/calls',
      data: <String, dynamic>{
        'initiatorName': initiatorName,
        'callType': callType,
      },
    );
    final Map<String, dynamic> data = Map<String, dynamic>.from(
      response.data as Map,
    );
    return AdminCallSession.fromJson(
      Map<String, dynamic>.from(data['call'] as Map? ?? <String, dynamic>{}),
    );
  }

  Future<void> acceptCall(String chatId, String callId) async {
    await _updateCallStatus(chatId, callId, 'active');
  }

  Future<void> rejectCall(String chatId, String callId) async {
    await _updateCallStatus(chatId, callId, 'rejected');
  }

  Future<void> endCall(String chatId, String callId, int endedBy) async {
    await _updateCallStatus(chatId, callId, 'ended', endedBy: endedBy);
  }

  Future<void> _updateCallStatus(
    String chatId,
    String callId,
    String status, {
    int? endedBy,
  }) async {
    await _client.post(
      '${ApiConfig.adminSupportSessions}/$chatId/calls/$callId/status',
      data: <String, dynamic>{
        'status': status,
        ...?endedBy == null ? null : <String, dynamic>{'endedBy': endedBy},
      },
    );
  }
}
