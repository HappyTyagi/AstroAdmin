import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  // static const String baseUrl = 'http://192.168.29.235:1234';
  static String get baseUrl => _env('BASE_URL', 'http://192.168.29.235:1234');

  static const String sendOtp = '/otp/send';
  static const String verifyOtp = '/otp/verify';
  static String get adminSupportMobileNo =>
      _env('ADMIN_MOBILE_NO', '8057700080');
  static String get panditSupportMobileNo =>
      _env('PANDIT_MOBILE_NO', '7852040757');
  static const String adminPujaBookings = '/api/web/puja/bookings';
  static const String adminRemedyBookings = '/api/web/remides/bookings';
  static const String adminSupportRtmToken = '/api/admin-support/rtm/token';
  static const String adminSupportSessionInit =
      '/api/admin-support/sessions/init';
  static const String adminSupportAdminSessions =
      '/api/admin-support/sessions/admin';
  static const String adminSupportSessions = '/api/admin-support/sessions';
  static const String adminSupportIncomingCalls =
      '/api/admin-support/calls/incoming';
  static const String adminSupportMediaUpload =
      '/api/admin-support/media/upload';
  static const String adminSupportMediaServe = '/api/admin-support/media';
  static const String dashboard = '/astrology/dashboard';
  static const String getProfile = '/profile/get';
  static const String getTodayPanchang =
      '/api/v1/astro-services/panchang/today';
  static const String fullKundliCalculate =
      '/api/v1/astro-services/kundli/calculate';
  static const String predictionDailyHoroscope =
      '/api/v1/astro-services/prediction/daily-horoscope';
  static const String agoraAppId = 'cbe31f2b8684484a92cdcb6b81ca8ab6';
  static const String agoraRtcToken = '/api/mobile/call/agora-token';
  static const String sendNotification = '/notification/send';
  static const String sendNotificationByMobile = '/notification/send-by-mobile';
  static const String chatPendingNotifications = '/notification/chat/pending';
  static const String chatAckNotifications = '/notification/chat/ack';

  static Map<String, String> get headers => <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static String _env(String key, String fallback) {
    final String raw = dotenv.env[key]?.trim() ?? '';
    return raw.isEmpty ? fallback : raw;
  }
}
