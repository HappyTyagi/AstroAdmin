import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

class ApiClient {
  ApiClient._internal();

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: ApiConfig.headers,
    ),
  );

  String? _token;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('token');
    if (stored != null && stored.trim().isNotEmpty) {
      _token = stored.trim();
    }
  }

  Future<void> setToken(String token) async {
    _token = token.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _token!);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    await _ensureHeaders();
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    await _ensureHeaders();
    return _dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<dynamic>> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    await _ensureHeaders();
    return _dio.put(path, data: data, queryParameters: queryParameters);
  }

  Future<void> _ensureHeaders() async {
    if (_token == null || _token!.isEmpty) {
      await loadToken();
    }
    if (_token != null && _token!.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $_token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
    debugPrint('[AstroAdmin API] Headers ready for ${_dio.options.baseUrl}');
  }
}
