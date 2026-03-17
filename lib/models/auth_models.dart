class OtpSendResponse {
  final bool success;
  final String message;
  final String sessionId;

  const OtpSendResponse({
    required this.success,
    required this.message,
    required this.sessionId,
  });

  factory OtpSendResponse.fromJson(Map<String, dynamic> json) {
    return OtpSendResponse(
      success: json['success'] == true,
      message: (json['message'] ?? 'OTP sent successfully').toString(),
      sessionId: (json['sessionId'] ?? '').toString(),
    );
  }
}

class AuthSession {
  final bool success;
  final String message;
  final String token;
  final String refreshToken;
  final int? userId;
  final String mobileNo;
  final String? name;
  final String? email;
  final String? role;

  const AuthSession({
    required this.success,
    required this.message,
    required this.token,
    required this.refreshToken,
    required this.mobileNo,
    this.userId,
    this.name,
    this.email,
    this.role,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      success: json['success'] == null ? true : json['success'] == true,
      message: (json['message'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
      refreshToken: (json['refreshToken'] ?? '').toString(),
      userId: json['userId'] is int
          ? json['userId'] as int
          : int.tryParse((json['userId'] ?? json['id'] ?? '').toString()),
      mobileNo: (json['mobileNo'] ?? '').toString(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      role:
          (json['role'] ?? (json['user'] is Map ? json['user']['role'] : null))
              ?.toString(),
    );
  }
}
