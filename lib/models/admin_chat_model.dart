class AdminChatSession {
  final String chatId;
  final int userId;
  final String userName;
  final String? userAvatar;
  final String? userPhone;
  final String lastMessage;
  final String lastMessageType;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isUserOnline;
  final String? rtmChannelName;
  final String? userRtmId;
  final String? adminRtmId;
  final int? adminUserId;
  final DateTime? userLastSeenAt;

  const AdminChatSession({
    required this.chatId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.userPhone,
    required this.lastMessage,
    required this.lastMessageType,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isUserOnline = false,
    this.rtmChannelName,
    this.userRtmId,
    this.adminRtmId,
    this.adminUserId,
    this.userLastSeenAt,
  });

  factory AdminChatSession.fromJson(Map<String, dynamic> json) {
    return AdminChatSession(
      chatId: (json['chatId'] ?? '').toString(),
      userId: json['userId'] is int
          ? json['userId'] as int
          : int.tryParse((json['userId'] ?? '0').toString()) ?? 0,
      userName: (json['userName'] ?? 'Unknown User').toString(),
      userAvatar: json['userAvatar']?.toString(),
      userPhone: json['userPhone']?.toString(),
      lastMessage: (json['lastMessage'] ?? '').toString(),
      lastMessageType: (json['lastMessageType'] ?? 'text').toString(),
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.tryParse(json['lastMessageTime'].toString()) ??
              DateTime.now()
          : DateTime.now(),
      unreadCount: json['unreadCount'] is int
          ? json['unreadCount'] as int
          : int.tryParse((json['unreadCount'] ?? '0').toString()) ?? 0,
      isUserOnline: json['isUserOnline'] == true,
      rtmChannelName: json['rtmChannelName']?.toString(),
      userRtmId: json['userRtmId']?.toString(),
      adminRtmId: json['adminRtmId']?.toString(),
      adminUserId: json['adminUserId'] is int
          ? json['adminUserId'] as int
          : int.tryParse((json['adminUserId'] ?? '').toString()),
      userLastSeenAt: json['userLastSeenAt'] != null
          ? DateTime.tryParse(json['userLastSeenAt'].toString())
          : null,
    );
  }
}

class AdminMessage {
  final String id;
  final String chatId;
  final int senderId;
  final String senderName;
  final String senderRole;
  final String? senderAvatar;
  final String messageType;
  final String content;
  final String? mediaUrl;
  final String? fileName;
  final int? fileSize;
  final int? mediaDuration;
  final DateTime timestamp;
  final bool isRead;

  const AdminMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    this.senderAvatar,
    required this.messageType,
    required this.content,
    this.mediaUrl,
    this.fileName,
    this.fileSize,
    this.mediaDuration,
    required this.timestamp,
    this.isRead = false,
  });

  factory AdminMessage.fromJson(Map<String, dynamic> json) {
    return AdminMessage(
      id: (json['id'] ?? '').toString(),
      chatId: (json['chatId'] ?? '').toString(),
      senderId: json['senderId'] is int
          ? json['senderId'] as int
          : int.tryParse((json['senderId'] ?? '0').toString()) ?? 0,
      senderName: (json['senderName'] ?? '').toString(),
      senderRole: (json['senderRole'] ?? 'user').toString(),
      senderAvatar: json['senderAvatar']?.toString(),
      messageType: (json['messageType'] ?? 'text').toString(),
      content: (json['content'] ?? '').toString(),
      mediaUrl: json['mediaUrl']?.toString(),
      fileName: json['fileName']?.toString(),
      fileSize: json['fileSize'] is int
          ? json['fileSize'] as int
          : int.tryParse((json['fileSize'] ?? '').toString()),
      mediaDuration: json['mediaDuration'] is int
          ? json['mediaDuration'] as int
          : int.tryParse((json['mediaDuration'] ?? '').toString()),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'senderAvatar': senderAvatar,
      'messageType': messageType,
      'content': content,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'mediaDuration': mediaDuration,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }
}

class AdminCallSession {
  final String id;
  final String chatId;
  final int initiatorId;
  final int receiverId;
  final String initiatorName;
  final String callType;
  final String status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? endedAt;

  const AdminCallSession({
    required this.id,
    required this.chatId,
    required this.initiatorId,
    required this.receiverId,
    required this.initiatorName,
    required this.callType,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.endedAt,
  });

  factory AdminCallSession.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return AdminCallSession(
      id: (json['id'] ?? '').toString(),
      chatId: (json['chatId'] ?? '').toString(),
      initiatorId: json['initiatorId'] is int
          ? json['initiatorId'] as int
          : int.tryParse((json['initiatorId'] ?? '0').toString()) ?? 0,
      receiverId: json['receiverId'] is int
          ? json['receiverId'] as int
          : int.tryParse((json['receiverId'] ?? '0').toString()) ?? 0,
      initiatorName: (json['initiatorName'] ?? 'User').toString(),
      callType: (json['callType'] ?? 'audio').toString(),
      status: (json['status'] ?? 'incoming').toString(),
      createdAt: parseDate(json['createdAt']),
      acceptedAt: parseNullableDate(json['acceptedAt']),
      endedAt: parseNullableDate(json['endedAt']),
    );
  }
}
