import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';
import 'api_client.dart';
import 'api_config.dart';

class AuthService {
  static const String _mobileKey = 'mobileNo';
  static const String _userIdKey = 'userId';
  static const String _nameKey = 'name';
  static const String _emailKey = 'email';
  static const String _roleKey = 'role';
  static const String _refreshTokenKey = 'refreshToken';

  final ApiClient _client = ApiClient();

  Dio _createDio() {
    return Dio(
      BaseOptions(
        headers: ApiConfig.headers,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  }

  Future<OtpSendResponse> sendMobileOtp(String mobileNo) async {
    try {
      final Dio dio = _createDio();
      final Response<dynamic> response = await dio.post(
        '${ApiConfig.baseUrl}${ApiConfig.sendOtp}',
        data: <String, dynamic>{'mobileNo': mobileNo},
        options: Options(
          contentType: 'application/json',
          headers: <String, String>{'accept': '*/*'},
        ),
      );

      if (response.statusCode == 200) {
        return OtpSendResponse.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }

      throw Exception('Failed to send OTP: ${response.statusMessage}');
    } catch (error) {
      throw Exception('Mobile OTP error: $error');
    }
  }

  Future<AuthSession> verifyMobileOtp({
    required String mobileNo,
    required String otp,
    required String sessionId,
  }) async {
    try {
      final Dio dio = _createDio();
      final Response<dynamic> response = await dio.post(
        '${ApiConfig.baseUrl}${ApiConfig.verifyOtp}',
        data: <String, dynamic>{
          'mobileNo': mobileNo,
          'otp': otp,
          'sessionId': sessionId,
        },
        options: Options(
          contentType: 'application/json',
          headers: <String, String>{'accept': '*/*'},
        ),
      );

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(response.data as Map);
      debugPrint('AstroAdmin OTP Verification Response: $data');

      if (response.statusCode == 200) {
        final AuthSession session = AuthSession.fromJson(data);
        return AuthSession(
          success: session.success,
          message: session.message,
          token: session.token,
          refreshToken: session.refreshToken,
          mobileNo: session.mobileNo.isEmpty ? mobileNo : session.mobileNo,
          userId: session.userId,
          name: session.name,
          email: session.email,
          role: session.role,
        );
      }

      return AuthSession(
        success: false,
        message: (data['message'] ?? 'OTP verification failed').toString(),
        token: '',
        refreshToken: '',
        mobileNo: mobileNo,
      );
    } catch (error) {
      throw Exception('OTP verification error: $error');
    }
  }

  Future<void> saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await _client.setToken(session.token);
    await prefs.setString(_mobileKey, session.mobileNo);
    await prefs.setString(_refreshTokenKey, session.refreshToken);
    if (session.userId != null) {
      await prefs.setInt(_userIdKey, session.userId!);
    }
    if ((session.name ?? '').trim().isNotEmpty) {
      await prefs.setString(_nameKey, session.name!.trim());
    }
    if ((session.email ?? '').trim().isNotEmpty) {
      await prefs.setString(_emailKey, session.email!.trim());
    }
    if ((session.role ?? '').trim().isNotEmpty) {
      await prefs.setString(_roleKey, session.role!.trim().toUpperCase());
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await _client.clearToken();
    await prefs.remove(_mobileKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_refreshTokenKey);
  }

  Future<bool> hasValidSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getInt(_userIdKey);
    return token != null &&
        token.trim().isNotEmpty &&
        userId != null &&
        userId > 0;
  }

  Future<bool> isCurrentUserAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final role = (prefs.getString(_roleKey) ?? '').trim().toUpperCase();
    final mobile = (prefs.getString(_mobileKey) ?? '').trim();
    return role == 'ADMIN' || mobile == ApiConfig.adminSupportMobileNo;
  }

  bool hasAdminAccess(AuthSession session) {
    final role = (session.role ?? '').trim().toUpperCase();
    return role == 'ADMIN' ||
        session.mobileNo.trim() == ApiConfig.adminSupportMobileNo;
  }

  Future<Map<String, String>> readStoredProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return <String, String>{
      'name': prefs.getString(_nameKey) ?? 'Admin',
      'mobileNo': prefs.getString(_mobileKey) ?? '',
      'email': prefs.getString(_emailKey) ?? '',
      'role': prefs.getString(_roleKey) ?? '',
    };
  }
}
