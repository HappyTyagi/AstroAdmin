import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/admin_booking_models.dart';
import '../models/admin_chat_model.dart';
import '../models/puja_call_models.dart';
import '../services/api_config.dart';
import '../services/admin_booking_service.dart';
import '../services/admin_chat_service.dart';
import '../services/app_preferences.dart';
import '../services/auth_service.dart';
import '../services/chat_push_service.dart';
import '../services/puja_call_service.dart';
import '../services/push_notification_bootstrap_service.dart';
import '../theme/app_theme.dart';
import 'admin_user_astro_profile_screen.dart';
import 'puja_video_call_screen.dart';
import 'support_call_screen.dart';

enum _BookingTimelineFilter { upcoming, complete }

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  bool _isHindi = AppPreferences.isHindiNotifier.value;

  @override
  void initState() {
    super.initState();
    AppPreferences.isHindiNotifier.addListener(_onLanguageChanged);
    PushNotificationBootstrapService.syncPendingChatNotifications();
  }

  @override
  void dispose() {
    AppPreferences.isHindiNotifier.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {
      _isHindi = AppPreferences.isHindiNotifier.value;
    });
  }

  String _tr(String en, String hi) => _isHindi ? hi : en;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final List<String> titles = <String>[
      _tr('All Chat', 'सभी चैट'),
      _tr('Booked Puja', 'बुक्ड पूजा'),
      _tr('Booked Remedies', 'बुक्ड रेमेडीज'),
      _tr('Setting', 'सेटिंग'),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        toolbarHeight: 74,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              titles[_currentIndex],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              _tr('AstroAdmin workspace', 'एस्ट्रोएडमिन वर्कस्पेस'),
              style: TextStyle(
                fontSize: 12.5,
                color: AdminAppTheme.muted.withValues(alpha: 0.88),
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: AdminAppTheme.pageBackdrop(isDark: dark),
        child: _buildCurrentPage(),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (int index) {
              setState(() => _currentIndex = index);
            },
            destinations: <NavigationDestination>[
              NavigationDestination(
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: const Icon(Icons.chat_bubble_rounded),
                label: _tr('All Chat', 'सभी चैट'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.temple_buddhist_outlined),
                selectedIcon: const Icon(Icons.temple_buddhist_rounded),
                label: _tr('Booked Puja', 'बुक्ड पूजा'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.auto_awesome_outlined),
                selectedIcon: const Icon(Icons.auto_awesome_rounded),
                label: _tr('Booked Remedies', 'बुक्ड रेमेडीज'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings_rounded),
                label: _tr('Setting', 'सेटिंग'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return const _AllChatsTab();
      case 1:
        return const _BookedPujaTab();
      case 2:
        return const _BookedRemediesTab();
      default:
        return _AdminSettingsTab(isHindi: _isHindi);
    }
  }
}

class _AllChatsTab extends StatefulWidget {
  const _AllChatsTab();

  @override
  State<_AllChatsTab> createState() => _AllChatsTabState();
}

class _AllChatsTabState extends State<_AllChatsTab> {
  final AdminChatService _chatService = AdminChatService();
  int _refreshSeed = 0;

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _refreshSeed++);
    await Future<void>.delayed(const Duration(milliseconds: 220));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminChatSession>>(
      key: ValueKey<int>(_refreshSeed),
      stream: _chatService.getAllChatsForAdmin(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<AdminChatSession>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const <Widget>[
                    SizedBox(height: 240),
                    Center(child: CircularProgressIndicator()),
                  ],
                ),
              );
            }
            if (snapshot.hasError) {
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: <Widget>[
                    _StateMessage(
                      icon: Icons.error_outline_rounded,
                      title: 'Unable to load chats',
                      subtitle:
                          'Please check Firebase connection and try again.',
                    ),
                  ],
                ),
              );
            }
            final List<AdminChatSession> chats =
                snapshot.data ?? <AdminChatSession>[];
            if (chats.isEmpty) {
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const <Widget>[
                    _StateMessage(
                      icon: Icons.mark_chat_unread_outlined,
                      title: 'No chats yet',
                      subtitle:
                          'User conversations will appear here automatically.',
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                itemCount: chats.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) {
                  final AdminChatSession chat = chats[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _AdminChatDetailScreen(chat: chat),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: AdminAppTheme.glassCard(),
                      child: Row(
                        children: <Widget>[
                          Stack(
                            children: <Widget>[
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: AdminAppTheme.royal.withValues(
                                  alpha: 0.12,
                                ),
                                backgroundImage:
                                    (chat.userAvatar ?? '').trim().isNotEmpty
                                    ? NetworkImage(chat.userAvatar!)
                                    : null,
                                child: (chat.userAvatar ?? '').trim().isEmpty
                                    ? Text(
                                        chat.userName.isEmpty
                                            ? 'U'
                                            : chat.userName[0].toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AdminAppTheme.royal,
                                        ),
                                      )
                                    : null,
                              ),
                              if (chat.isUserOnline)
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: AdminAppTheme.success,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        chat.userName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatDateTime(chat.lastMessageTime),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AdminAppTheme.muted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  chat.userPhone?.trim().isNotEmpty == true
                                      ? chat.userPhone!
                                      : 'User ID: ${chat.userId}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AdminAppTheme.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  chat.lastMessage.isEmpty
                                      ? 'Tap to open conversation'
                                      : chat.lastMessage,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    height: 1.35,
                                    color: AdminAppTheme.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (chat.unreadCount > 0) ...<Widget>[
                            const SizedBox(width: 10),
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: AdminAppTheme.gold,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${chat.unreadCount}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
    );
  }
}

class _AdminChatDetailScreen extends StatefulWidget {
  const _AdminChatDetailScreen({required this.chat});

  final AdminChatSession chat;

  @override
  State<_AdminChatDetailScreen> createState() => _AdminChatDetailScreenState();
}

class _AdminChatDetailScreenState extends State<_AdminChatDetailScreen> {
  final AdminChatService _chatService = AdminChatService();
  final AuthService _authService = AuthService();
  final ChatPushService _chatPushService = ChatPushService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _adminName = 'Admin';
  int _adminUserId = 1;
  bool _sending = false;
  bool _startingAudioCall = false;
  bool _startingVideoCall = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    PushNotificationBootstrapService.syncPendingChatNotifications();
    // Don't let read-sync failures block opening the chat screen.
    _chatService.markMessagesAsRead(widget.chat.chatId);
  }

  Future<void> _loadProfile() async {
    final Map<String, String> profile = await _authService.readStoredProfile();
    if (!mounted) {
      return;
    }
    final int storedUserId = await _readCurrentUserId();
    if (!mounted) {
      return;
    }
    setState(() {
      _adminName = profile['name'] ?? 'Admin';
      _adminUserId = storedUserId > 0 ? storedUserId : 1;
    });
  }

  Future<int> _readCurrentUserId() async {
    return (await SharedPreferences.getInstance()).getInt('userId') ?? 1;
  }

  bool get _isHindi => AppPreferences.isHindiNotifier.value;

  String _tr(String en, String hi) => _isHindi ? hi : en;

  String get _chatInfoText => _tr(
    'Admin support chat. You can send text messages and start audio/video calls.',
    'एडमिन सपोर्ट चैट। आप टेक्स्ट संदेश भेज सकते हैं और ऑडियो/वीडियो कॉल शुरू कर सकते हैं।',
  );

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _notifyUser({
    required String messageType,
    required String content,
    Map<String, dynamic>? actionData,
  }) async {
    await _chatPushService.sendChatNotificationToUser(
      recipientUserId: widget.chat.userId,
      recipientMobileNo: widget.chat.userPhone,
      senderName: _adminName,
      messageType: messageType,
      content: content,
      notificationType: 'SESSION',
      actionData:
          actionData ??
          <String, dynamic>{
            'source': 'chat',
            'chatId': widget.chat.chatId,
            'targetRole': 'user',
            'callerName': _adminName,
          },
    );
  }

  Map<String, dynamic> _buildChatActionData(AdminMessage message) {
    return <String, dynamic>{
      'source': 'chat',
      'targetRole': 'user',
      'chatId': message.chatId,
      'id': message.id,
      'senderId': message.senderId,
      'senderName': message.senderName,
      'senderRole': message.senderRole,
      'messageType': message.messageType,
      'content': message.content,
      'timestamp': message.timestamp.toIso8601String(),
      if ((message.mediaUrl ?? '').trim().isNotEmpty)
        'mediaUrl': message.mediaUrl,
      if ((message.fileName ?? '').trim().isNotEmpty)
        'fileName': message.fileName,
      if ((message.fileSize ?? 0) > 0) 'fileSize': message.fileSize,
      if ((message.mediaDuration ?? 0) > 0)
        'mediaDuration': message.mediaDuration,
    };
  }

  Future<void> _send() async {
    final String text = _messageController.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      final sentMessage = await _chatService.sendTextMessage(
        chatId: widget.chat.chatId,
        content: text,
        senderName: _adminName,
        senderId: _adminUserId,
      );
      await _notifyUser(
        messageType: 'text',
        content: text,
        actionData: _buildChatActionData(sentMessage),
      );
      _messageController.clear();
      _chatService.markMessagesAsRead(widget.chat.chatId);
    } catch (e) {
      _showError(
        _tr('Failed to send message: $e', 'संदेश भेजने में समस्या हुई: $e'),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _startSupportCall(String callType) async {
    final bool isVideo = callType == 'video';
    if ((isVideo && _startingVideoCall) || (!isVideo && _startingAudioCall)) {
      return;
    }

    setState(() {
      if (isVideo) {
        _startingVideoCall = true;
      } else {
        _startingAudioCall = true;
      }
    });

    try {
      final AdminCallSession callSession = await _chatService.startCall(
        chatId: widget.chat.chatId,
        initiatorName: _adminName,
        callType: callType,
      );
      await _chatPushService.sendChatNotificationToUser(
        recipientUserId: widget.chat.userId,
        recipientMobileNo: widget.chat.userPhone,
        senderName: _adminName,
        messageType: 'text',
        content: isVideo ? 'Incoming video call' : 'Incoming audio call',
        notificationType: 'SESSION',
        actionData: <String, dynamic>{
          'source': 'call',
          'chatId': widget.chat.chatId,
          'callId': callSession.id,
          'callType': callType,
          'targetRole': 'user',
          'callerName': _adminName,
        },
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SupportCallScreen(
            chatId: widget.chat.chatId,
            callId: callSession.id,
            callType: callType,
            localUserId: _adminUserId,
            remoteUserId: widget.chat.userId,
            participantName: widget.chat.userName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Failed to start ${isVideo ? "video" : "audio"} call: $e',
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          if (isVideo) {
            _startingVideoCall = false;
          } else {
            _startingAudioCall = false;
          }
        });
      }
    }
  }

  Future<void> _openUserAstroInsights() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminUserAstroProfileScreen(
          userId: widget.chat.userId,
          userName: widget.chat.userName,
          userPhone: widget.chat.userPhone,
          userAvatar: widget.chat.userAvatar,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String phoneOrId = widget.chat.userPhone?.trim().isNotEmpty == true
        ? widget.chat.userPhone!
        : '${_tr('User ID', 'यूज़र आईडी')}: ${widget.chat.userId}';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF0F1219)
            : AdminAppTheme.gold.withValues(alpha: 0.26),
        foregroundColor: isDark ? Colors.white : AdminAppTheme.royal,
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.transparent,
              child: _buildUserAvatar(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _openUserAstroInsights,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.chat.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        phoneOrId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : AdminAppTheme.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _startingAudioCall
                ? null
                : () => _startSupportCall('audio'),
            tooltip: _tr('Audio call', 'ऑडियो कॉल'),
            icon: _startingAudioCall
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.call_rounded),
          ),
          IconButton(
            onPressed: _startingVideoCall
                ? null
                : () => _startSupportCall('video'),
            tooltip: _tr('Video call', 'वीडियो कॉल'),
            icon: _startingVideoCall
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.videocam_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: AdminAppTheme.pageBackdrop(isDark: isDark),
        child: Column(
          children: <Widget>[
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B1F2B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: isDark ? AdminAppTheme.gold : AdminAppTheme.royal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _chatInfoText,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : AdminAppTheme.royal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<AdminMessage>>(
                stream: _chatService.getMessagesStream(widget.chat.chatId),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<AdminMessage>> snapshot,
                    ) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return _StateMessage(
                          icon: Icons.error_outline_rounded,
                          title: _tr(
                            'Unable to load messages',
                            'मैसेज लोड नहीं हुए',
                          ),
                          subtitle: _tr(
                            'Please try again. If it persists, check chat configuration.',
                            'कृपया दोबारा प्रयास करें। समस्या जारी रहे तो चैट कॉन्फ़िगरेशन जांचें।',
                          ),
                        );
                      }
                      final List<AdminMessage> messages =
                          snapshot.data ?? <AdminMessage>[];
                      if (messages.isEmpty) {
                        return _StateMessage(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: _tr(
                            'No messages yet',
                            'अभी तक कोई संदेश नहीं है',
                          ),
                          subtitle: _tr(
                            'Send a message to start the conversation.',
                            'बातचीत शुरू करने के लिए संदेश भेजें।',
                          ),
                        );
                      }
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          );
                        }
                      });
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        itemCount: messages.length,
                        itemBuilder: (BuildContext context, int index) {
                          final AdminMessage message = messages[index];
                          final bool isAdmin = message.senderRole == 'admin';
                          return _buildMessageBubble(
                            message: message,
                            isAdmin: isAdmin,
                            isDark: isDark,
                          );
                        },
                      );
                    },
              ),
            ),
            _buildInputBar(isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar() {
    final String source = (widget.chat.userAvatar ?? '').trim();
    if (source.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          source,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stackTrace) => _buildAvatarFallback(),
        ),
      );
    }
    return _buildAvatarFallback();
  }

  Widget _buildAvatarFallback() {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: AdminAppTheme.royal,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        widget.chat.userName.isEmpty ? 'U' : widget.chat.userName[0],
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required AdminMessage message,
    required bool isAdmin,
    required bool isDark,
  }) {
    final Color bubbleColor = isAdmin
        ? (isDark ? const Color(0xFF2A2E3B) : AdminAppTheme.cream)
        : (isDark ? const Color(0xFF1B1F2B) : Colors.white);
    final Color nameColor = isAdmin ? AdminAppTheme.gold : AdminAppTheme.royal;

    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : AdminAppTheme.royal.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              message.senderName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: nameColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message.content,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: isDark ? Colors.white : AdminAppTheme.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : AdminAppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final bool isDark =
            Theme.of(sheetContext).brightness == Brightness.dark;
        return Container(
          height: 220,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF171A24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.photo_library_rounded),
                title: Text(_tr('Photos', 'फोटो')),
                onTap: () => _showAttachmentComingSoon(_tr('Photos', 'फोटो')),
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.camera_alt_rounded),
                title: Text(_tr('Camera', 'कैमरा')),
                onTap: () => _showAttachmentComingSoon(_tr('Camera', 'कैमरा')),
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.description_rounded),
                title: Text(_tr('Document', 'डॉक्यूमेंट')),
                onTap: () =>
                    _showAttachmentComingSoon(_tr('Document', 'डॉक्यूमेंट')),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAttachmentComingSoon(String label) {
    Navigator.of(context).pop();
    _showError(
      _tr(
        '$label attachment will be enabled next.',
        '$label अटैचमेंट अगली अपडेट में उपलब्ध होगा।',
      ),
    );
  }

  Widget _buildInputBar({required bool isDark}) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1F2B) : AdminAppTheme.royal,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: _showAttachmentOptions,
              tooltip: _tr('Attach', 'अटैच'),
              icon: const Icon(Icons.attach_file, color: AdminAppTheme.gold),
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: _tr('Type a reply…', 'उत्तर टाइप करें…'),
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: _sending ? null : _send,
              tooltip: _tr('Send', 'भेजें'),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AdminAppTheme.gold,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: AdminAppTheme.gold),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookedPujaTab extends StatefulWidget {
  const _BookedPujaTab();

  @override
  State<_BookedPujaTab> createState() => _BookedPujaTabState();
}

class _BookedPujaTabState extends State<_BookedPujaTab> {
  final AdminBookingService _bookingService = AdminBookingService();
  late Future<List<AdminPujaBooking>> _future;
  _BookingTimelineFilter _selectedFilter = _BookingTimelineFilter.upcoming;

  @override
  void initState() {
    super.initState();
    _future = _bookingService.fetchPujaBookings();
  }

  Future<void> _reload() async {
    setState(() => _future = _bookingService.fetchPujaBookings());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminPujaBooking>>(
      future: _future,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<AdminPujaBooking>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _StateMessage(
                icon: Icons.temple_buddhist_outlined,
                title: 'Unable to load booked puja',
                subtitle: 'Please check the admin booking API and try again.',
                onRetry: _reload,
              );
            }
            final List<AdminPujaBooking> items =
                snapshot.data ?? <AdminPujaBooking>[];
            if (items.isEmpty) {
              return const _StateMessage(
                icon: Icons.event_busy_outlined,
                title: 'No puja bookings',
                subtitle: 'Booked puja records will appear here.',
              );
            }
            final List<AdminPujaBooking> upcomingItems = items
                .where((AdminPujaBooking item) => !_isPujaCompleted(item))
                .toList();
            final List<AdminPujaBooking> completedItems = items
                .where(_isPujaCompleted)
                .toList();
            final bool showUpcoming =
                _selectedFilter == _BookingTimelineFilter.upcoming;
            final List<AdminPujaBooking> filteredItems = showUpcoming
                ? upcomingItems
                : completedItems;
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: <Widget>[
                  _BookingFilterHeader(
                    title: 'Puja Timeline',
                    subtitle:
                        'Review scheduled ceremonies and completed rituals.',
                    primaryLabel: 'Upcoming',
                    primaryCount: upcomingItems.length,
                    secondaryLabel: 'Complete',
                    secondaryCount: completedItems.length,
                    isPrimarySelected: showUpcoming,
                    onPrimaryTap: () {
                      setState(
                        () => _selectedFilter = _BookingTimelineFilter.upcoming,
                      );
                    },
                    onSecondaryTap: () {
                      setState(
                        () => _selectedFilter = _BookingTimelineFilter.complete,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (filteredItems.isEmpty)
                    _FilteredEmptyState(
                      icon: showUpcoming
                          ? Icons.upcoming_outlined
                          : Icons.verified_rounded,
                      title: showUpcoming
                          ? 'No upcoming puja'
                          : 'No completed puja',
                      subtitle: showUpcoming
                          ? 'Freshly scheduled puja bookings will appear here.'
                          : 'Completed puja records will appear here.',
                    )
                  else
                    ...filteredItems.map(
                      (AdminPujaBooking item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PujaBookingCard(item: item),
                      ),
                    ),
                ],
              ),
            );
          },
    );
  }
}

class _BookedRemediesTab extends StatefulWidget {
  const _BookedRemediesTab();

  @override
  State<_BookedRemediesTab> createState() => _BookedRemediesTabState();
}

class _BookedRemediesTabState extends State<_BookedRemediesTab> {
  final AdminBookingService _bookingService = AdminBookingService();
  late Future<List<AdminRemedyBooking>> _future;
  _BookingTimelineFilter _selectedFilter = _BookingTimelineFilter.upcoming;

  @override
  void initState() {
    super.initState();
    _future = _bookingService.fetchRemedyBookings();
  }

  Future<void> _reload() async {
    setState(() => _future = _bookingService.fetchRemedyBookings());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminRemedyBooking>>(
      future: _future,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<AdminRemedyBooking>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _StateMessage(
                icon: Icons.auto_awesome_outlined,
                title: 'Unable to load remedy bookings',
                subtitle: 'Please check the admin remedies API and try again.',
                onRetry: _reload,
              );
            }
            final List<AdminRemedyBooking> items =
                snapshot.data ?? <AdminRemedyBooking>[];
            if (items.isEmpty) {
              return const _StateMessage(
                icon: Icons.inventory_2_outlined,
                title: 'No remedy bookings',
                subtitle: 'Paid remedy orders will appear here.',
              );
            }
            final List<AdminRemedyBooking> upcomingItems = items
                .where((AdminRemedyBooking item) => !_isRemedyCompleted(item))
                .toList();
            final List<AdminRemedyBooking> completedItems = items
                .where(_isRemedyCompleted)
                .toList();
            final bool showUpcoming =
                _selectedFilter == _BookingTimelineFilter.upcoming;
            final List<AdminRemedyBooking> filteredItems = showUpcoming
                ? upcomingItems
                : completedItems;
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: <Widget>[
                  _BookingFilterHeader(
                    title: 'Remedy Orders',
                    subtitle:
                        'Separate active deliveries from completed orders.',
                    primaryLabel: 'Upcoming',
                    primaryCount: upcomingItems.length,
                    secondaryLabel: 'Complete',
                    secondaryCount: completedItems.length,
                    isPrimarySelected: showUpcoming,
                    onPrimaryTap: () {
                      setState(
                        () => _selectedFilter = _BookingTimelineFilter.upcoming,
                      );
                    },
                    onSecondaryTap: () {
                      setState(
                        () => _selectedFilter = _BookingTimelineFilter.complete,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (filteredItems.isEmpty)
                    _FilteredEmptyState(
                      icon: showUpcoming
                          ? Icons.local_shipping_outlined
                          : Icons.check_circle_outline_rounded,
                      title: showUpcoming
                          ? 'No upcoming remedy orders'
                          : 'No completed remedy orders',
                      subtitle: showUpcoming
                          ? 'Orders in progress will appear here.'
                          : 'Delivered or completed remedy orders will appear here.',
                    )
                  else
                    ...filteredItems.map(
                      (AdminRemedyBooking item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RemedyBookingCard(item: item),
                      ),
                    ),
                ],
              ),
            );
          },
    );
  }
}

class _AdminSettingsTab extends StatefulWidget {
  final bool isHindi;

  const _AdminSettingsTab({required this.isHindi});

  @override
  State<_AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<_AdminSettingsTab> {
  final AuthService _authService = AuthService();
  late Future<Map<String, String>> _profileFuture;
  bool _isHindi = false;
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _isHindi = widget.isHindi;
    _isDark = AppPreferences.themeModeNotifier.value == ThemeMode.dark;
    _profileFuture = _authService.readStoredProfile();
  }

  String _tr(String en, String hi) => _isHindi ? hi : en;

  Future<void> _refreshProfile() async {
    setState(() => _profileFuture = _authService.readStoredProfile());
    await _profileFuture;
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr('Admin profile refreshed', 'एडमिन प्रोफ़ाइल रीफ्रेश हो गई'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _checkAccess() async {
    final bool hasAccess = await _authService.isCurrentUserAdmin();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasAccess
              ? _tr(
                  'Admin access is active for this account',
                  'इस अकाउंट के लिए एडमिन एक्सेस सक्रिय है',
                )
              : _tr(
                  'Admin access is missing for this account',
                  'इस अकाउंट में एडमिन एक्सेस उपलब्ध नहीं है',
                ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copySupportNumber() async {
    await Clipboard.setData(
      ClipboardData(text: ApiConfig.adminSupportMobileNo),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            'Support mobile ${ApiConfig.adminSupportMobileNo} copied',
            'सपोर्ट मोबाइल ${ApiConfig.adminSupportMobileNo} कॉपी हो गया',
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showAccessGuide() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AdminAppTheme.royal.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, -12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AdminAppTheme.muted.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _tr('Access & Security', 'एक्सेस और सुरक्षा'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                _tr(
                  'Use this panel only with approved admin numbers. Logout immediately after review work on shared devices.',
                  'इस पैनल का उपयोग केवल स्वीकृत एडमिन नंबर से करें। साझा डिवाइस पर काम खत्म होने पर तुरंत लॉगआउट करें।',
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: AdminAppTheme.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              _GuidePoint(
                icon: Icons.verified_user_rounded,
                text: _tr(
                  'OTP access is limited to approved admin accounts.',
                  'OTP एक्सेस केवल स्वीकृत एडमिन अकाउंट तक सीमित है।',
                ),
              ),
              _GuidePoint(
                icon: Icons.support_agent_rounded,
                text: _tr(
                  'Support mobile is available for urgent access checks.',
                  'तत्काल एक्सेस जांच के लिए सपोर्ट मोबाइल उपलब्ध है।',
                ),
              ),
              _GuidePoint(
                icon: Icons.logout_rounded,
                text: _tr(
                  'Sign out after completing booking or chat reviews.',
                  'बुकिंग या चैट समीक्षा पूरी होने पर साइन आउट करें।',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleLanguage(bool value) async {
    await AppPreferences.setHindi(value);
    if (!mounted) return;
    setState(() {
      _isHindi = value;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    await AppPreferences.setDarkMode(value);
    if (!mounted) return;
    setState(() {
      _isDark = value;
    });
  }

  Future<void> _logout() async {
    await _authService.clearSession();
    if (!mounted) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (Route<dynamic> _) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<Map<String, String>>(
      future: _profileFuture,
      builder: (BuildContext context, AsyncSnapshot<Map<String, String>> snapshot) {
        final Map<String, String> profile = snapshot.data ?? <String, String>{};
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AdminAppTheme.glassCard(
                isDark: dark,
                colors: <Color>[
                  Colors.white,
                  AdminAppTheme.gold.withValues(alpha: 0.18),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tr('Admin Profile', 'एडमिन प्रोफ़ाइल'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  _SettingsRow(
                    label: _tr('Name', 'नाम'),
                    value: profile['name'] ?? _tr('Admin', 'एडमिन'),
                  ),
                  _SettingsRow(
                    label: _tr('Mobile', 'मोबाइल'),
                    value: profile['mobileNo']?.isNotEmpty == true
                        ? profile['mobileNo']!
                        : '-',
                  ),
                  _SettingsRow(
                    label: _tr('Email', 'ईमेल'),
                    value: profile['email']?.isNotEmpty == true
                        ? profile['email']!
                        : '-',
                  ),
                  _SettingsRow(
                    label: _tr('Role', 'रोल'),
                    value: profile['role']?.isNotEmpty == true
                        ? profile['role']!
                        : 'ADMIN',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AdminAppTheme.glassCard(isDark: dark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tr('Quick Actions', 'त्वरित क्रियाएँ'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isHindi,
                    secondary: const Icon(Icons.language_rounded),
                    title: Text(_tr('Hindi Language', 'हिंदी भाषा')),
                    subtitle: Text(
                      _tr(
                        'Toggle Hindi / English labels',
                        'हिंदी / अंग्रेज़ी लेबल बदलें',
                      ),
                    ),
                    onChanged: _toggleLanguage,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isDark,
                    secondary: const Icon(Icons.dark_mode_rounded),
                    title: Text(_tr('Dark Theme', 'डार्क थीम')),
                    subtitle: Text(
                      _tr(
                        'Enable premium dark appearance',
                        'प्रीमियम डार्क रूप सक्षम करें',
                      ),
                    ),
                    onChanged: _toggleTheme,
                  ),
                  const Divider(height: 1),
                  _SettingsActionTile(
                    icon: Icons.refresh_rounded,
                    title: _tr('Refresh Profile', 'प्रोफ़ाइल रीफ्रेश करें'),
                    subtitle: _tr(
                      'Reload saved admin details from the device.',
                      'डिवाइस से सेव एडमिन जानकारी पुनः लोड करें।',
                    ),
                    onTap: _refreshProfile,
                  ),
                  _SettingsActionTile(
                    icon: Icons.verified_user_outlined,
                    title: _tr('Check Admin Access', 'एडमिन एक्सेस जांचें'),
                    subtitle: _tr(
                      'Confirm that the current account is still valid.',
                      'पुष्टि करें कि वर्तमान अकाउंट अभी भी मान्य है।',
                    ),
                    onTap: _checkAccess,
                  ),
                  _SettingsActionTile(
                    icon: Icons.content_copy_rounded,
                    title: _tr(
                      'Copy Support Mobile',
                      'सपोर्ट मोबाइल कॉपी करें',
                    ),
                    subtitle: _tr(
                      'Quickly copy the admin support number for follow-up.',
                      'फॉलो-अप के लिए एडमिन सपोर्ट नंबर जल्दी कॉपी करें।',
                    ),
                    onTap: _copySupportNumber,
                  ),
                  _SettingsActionTile(
                    icon: Icons.security_rounded,
                    title: _tr('Access & Security', 'एक्सेस और सुरक्षा'),
                    subtitle: _tr(
                      'View basic usage and session safety guidelines.',
                      'बुनियादी उपयोग और सत्र सुरक्षा निर्देश देखें।',
                    ),
                    onTap: _showAccessGuide,
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AdminAppTheme.glassCard(isDark: dark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _tr('Workspace Summary', 'वर्कस्पेस सारांश'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _tr(
                      'AstroAdmin now owns the dedicated admin flow: OTP login, all chats, booked puja, booked remedies, and admin settings.',
                      'AstroAdmin अब समर्पित एडमिन फ्लो संभालता है: OTP लॉगिन, सभी चैट, बुक्ड पूजा, बुक्ड रेमेडीज और सेटिंग।',
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: AdminAppTheme.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(_tr('Logout', 'लॉगआउट')),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PujaBookingCard extends StatelessWidget {
  const _PujaBookingCard({required this.item});

  final AdminPujaBooking item;

  bool _isJoinAllowed(DateTime slotTime) {
    final joinOpensAt = slotTime.subtract(const Duration(minutes: 10));
    return DateTime.now().isAfter(joinOpensAt);
  }

  Future<void> _join(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);
    final slotTime = item.slotTime;
    if (slotTime == null) {
      scaffold.showSnackBar(
        const SnackBar(content: Text('Slot time is not assigned yet.')),
      );
      return;
    }
    if (!_isJoinAllowed(slotTime)) {
      final joinOpensAt = slotTime.subtract(const Duration(minutes: 10));
      scaffold.showSnackBar(
        SnackBar(
          content: Text(
            'Join will open at ${DateFormat('dd MMM, hh:mm a').format(joinOpensAt)}',
          ),
        ),
      );
      return;
    }

    try {
      final PujaAgoraLink link = await PujaCallService().generateAgoraLink(
        bookingId: item.bookingId,
        callType: 'video',
      );
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PujaVideoCallScreen(
            appId: link.appId,
            token: link.token,
            channelName: link.channelName,
            uid: link.uid,
            callType: 'video',
          ),
        ),
      );
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String fallbackStatus = _isPujaCompleted(item)
        ? 'COMPLETED'
        : 'UPCOMING';
    final DateTime? slotTime = item.slotTime;
    final bool joinEnabled =
        !_isPujaCompleted(item) && slotTime != null && _isJoinAllowed(slotTime);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AdminAppTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.pujaName.isEmpty ? 'Puja' : item.pujaName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusChip(
                label: _displayStatus(item.status, fallback: fallbackStatus),
                color: _statusColor(item.status, fallback: fallbackStatus),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${item.userName} • ${item.mobileNumber}',
            style: const TextStyle(
              color: AdminAppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _InfoPill(
                icon: Icons.currency_rupee_rounded,
                label: '₹${item.totalPrice.toStringAsFixed(0)}',
              ),
              _InfoPill(
                icon: Icons.schedule_rounded,
                label: item.slotTime == null
                    ? 'Slot pending'
                    : DateFormat('dd MMM, hh:mm a').format(item.slotTime!),
              ),
              _InfoPill(
                icon: Icons.credit_card_rounded,
                label: item.paymentMethod.isEmpty
                    ? 'Payment N/A'
                    : item.paymentMethod,
              ),
              if (item.pujaOtp.trim().isNotEmpty)
                _InfoPill(
                  icon: Icons.password_rounded,
                  label: 'OTP ${item.pujaOtp}',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Booked ${item.bookedAt == null ? '-' : DateFormat('dd MMM yyyy, hh:mm a').format(item.bookedAt!)}',
            style: const TextStyle(fontSize: 12.5, color: AdminAppTheme.muted),
          ),
          if (item.transactionId.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Txn: ${item.transactionId}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AdminAppTheme.muted,
              ),
            ),
          ],
          if (!_isPujaCompleted(item)) ...<Widget>[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: joinEnabled
                      ? AdminAppTheme.gold
                      : Colors.grey.shade300,
                  foregroundColor: AdminAppTheme.ink,
                ),
                onPressed: joinEnabled ? () => _join(context) : null,
                icon: const Icon(Icons.video_call_rounded),
                label: const Text('Join Video'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RemedyBookingCard extends StatelessWidget {
  const _RemedyBookingCard({required this.item});

  final AdminRemedyBooking item;

  @override
  Widget build(BuildContext context) {
    final String fallbackStatus = _isRemedyCompleted(item)
        ? 'COMPLETED'
        : 'UPCOMING';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AdminAppTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.orderId,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusChip(
                label: _displayStatus(item.status, fallback: fallbackStatus),
                color: _statusColor(item.status, fallback: fallbackStatus),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${item.userName} • ${item.mobileNumber}',
            style: const TextStyle(
              color: AdminAppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.titles.join(', '),
            style: const TextStyle(fontSize: 14.5, height: 1.35),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _InfoPill(
                icon: Icons.shopping_bag_outlined,
                label: '${item.totalItems} item(s)',
              ),
              _InfoPill(
                icon: Icons.currency_rupee_rounded,
                label: '₹${item.totalAmount.toStringAsFixed(0)}',
              ),
              _InfoPill(
                icon: Icons.payments_outlined,
                label: item.paymentMethod.isEmpty
                    ? 'Payment N/A'
                    : item.paymentMethod,
              ),
            ],
          ),
          if (item.address.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              item.address,
              style: const TextStyle(
                fontSize: 12.5,
                color: AdminAppTheme.muted,
                height: 1.4,
              ),
            ),
          ],
          if (item.purchasedAt != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Purchased ${DateFormat('dd MMM yyyy, hh:mm a').format(item.purchasedAt!)}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AdminAppTheme.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BookingFilterHeader extends StatelessWidget {
  const _BookingFilterHeader({
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.primaryCount,
    required this.secondaryLabel,
    required this.secondaryCount,
    required this.isPrimarySelected,
    required this.onPrimaryTap,
    required this.onSecondaryTap,
  });

  final String title;
  final String subtitle;
  final String primaryLabel;
  final int primaryCount;
  final String secondaryLabel;
  final int secondaryCount;
  final bool isPrimarySelected;
  final VoidCallback onPrimaryTap;
  final VoidCallback onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AdminAppTheme.glassCard(
        colors: <Color>[
          Colors.white,
          AdminAppTheme.gold.withValues(alpha: 0.12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AdminAppTheme.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _BookingToggleButton(
                  label: primaryLabel,
                  count: primaryCount,
                  selected: isPrimarySelected,
                  onTap: onPrimaryTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BookingToggleButton(
                  label: secondaryLabel,
                  count: secondaryCount,
                  selected: !isPrimarySelected,
                  onTap: onSecondaryTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingToggleButton extends StatelessWidget {
  const _BookingToggleButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AdminAppTheme.midnight
                : AdminAppTheme.royal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AdminAppTheme.midnight
                  : AdminAppTheme.royal.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            children: <Widget>[
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : AdminAppTheme.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.92)
                      : AdminAppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminAppTheme.glassCard(),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 42, color: AdminAppTheme.royal),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13.5,
              color: AdminAppTheme.muted,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 56, color: AdminAppTheme.royal),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AdminAppTheme.muted,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AdminAppTheme.royal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AdminAppTheme.royal),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AdminAppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                color: AdminAppTheme.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AdminAppTheme.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AdminAppTheme.royal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AdminAppTheme.royal),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AdminAppTheme.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AdminAppTheme.muted,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: AdminAppTheme.royal.withValues(alpha: 0.08),
          ),
      ],
    );
  }
}

class _GuidePoint extends StatelessWidget {
  const _GuidePoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AdminAppTheme.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AdminAppTheme.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AdminAppTheme.ink,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final Duration difference = DateTime.now().difference(value);
  if (difference.inDays == 0) {
    return DateFormat('hh:mm a').format(value);
  }
  if (difference.inDays < 7) {
    return DateFormat('EEE').format(value);
  }
  return DateFormat('dd MMM').format(value);
}

String _normalizeStatus(String value) {
  return value.trim().toLowerCase();
}

bool _containsAnyKeyword(String value, List<String> keywords) {
  return keywords.any(value.contains);
}

bool _isFinalizedStatus(String value) {
  return _containsAnyKeyword(value, <String>[
    'complete',
    'completed',
    'done',
    'deliver',
    'success',
    'successful',
    'cancel',
    'failed',
    'refund',
    'closed',
  ]);
}

bool _isInProgressStatus(String value) {
  return _containsAnyKeyword(value, <String>[
    'pending',
    'process',
    'confirm',
    'schedule',
    'booked',
    'upcoming',
    'initiat',
    'assign',
    'pack',
    'ship',
    'dispatch',
    'purchase',
    'order',
    'new',
  ]);
}

bool _isPujaCompleted(AdminPujaBooking item) {
  final String status = _normalizeStatus(item.status);
  if (status.isNotEmpty) {
    if (_isFinalizedStatus(status)) {
      return true;
    }
    if (_isInProgressStatus(status)) {
      return false;
    }
  }
  if (item.slotTime != null) {
    return !item.slotTime!.isAfter(DateTime.now());
  }
  return false;
}

bool _isRemedyCompleted(AdminRemedyBooking item) {
  final String status = _normalizeStatus(item.status);
  if (status.isEmpty) {
    return true;
  }
  if (_isFinalizedStatus(status)) {
    return true;
  }
  if (_isInProgressStatus(status)) {
    return false;
  }
  return true;
}

Color _statusColor(String status, {required String fallback}) {
  final String normalized = _normalizeStatus(
    status.isEmpty ? fallback : status,
  );
  if (_containsAnyKeyword(normalized, <String>['cancel', 'failed', 'refund'])) {
    return AdminAppTheme.danger;
  }
  if (_isFinalizedStatus(normalized)) {
    return AdminAppTheme.success;
  }
  return AdminAppTheme.royal;
}

String _displayStatus(String status, {required String fallback}) {
  final String value = status.trim().isEmpty ? fallback : status.trim();
  return value.toUpperCase();
}
