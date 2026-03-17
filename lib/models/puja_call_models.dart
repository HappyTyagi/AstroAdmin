class PujaAgoraLink {
  final bool success;
  final String message;
  final String appId;
  final String token;
  final String channelName;
  final int uid;
  final int? expiresAtEpoch;

  const PujaAgoraLink({
    required this.success,
    required this.message,
    required this.appId,
    required this.token,
    required this.channelName,
    required this.uid,
    required this.expiresAtEpoch,
  });

  factory PujaAgoraLink.fromJson(Map<String, dynamic> json) {
    return PujaAgoraLink(
      success: json['success'] == true || json['status'] == true,
      message: (json['message'] ?? '').toString(),
      appId: (json['appId'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
      channelName: (json['channelName'] ?? '').toString(),
      uid: _readInt(json['uid']),
      expiresAtEpoch: _readIntNullable(json['expiresAtEpoch']),
    );
  }
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse((value ?? '0').toString()) ?? 0;
}

int? _readIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString());
}

