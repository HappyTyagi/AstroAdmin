import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_config.dart';

class AdminUserAstroService {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> getUserProfile(int userId) async {
    final response = await _client.get('${ApiConfig.getProfile}/$userId');
    return _toMap(response.data);
  }

  Future<Map<String, dynamic>> getDashboardByMobile(String mobileNo) async {
    final normalized = mobileNo.trim();
    if (normalized.isEmpty) {
      throw Exception('User mobile is required for dashboard');
    }
    final response = await _client.get(
      ApiConfig.dashboard,
      queryParameters: <String, dynamic>{'mobileNo': normalized},
    );
    return _toMap(response.data);
  }

  Future<Map<String, dynamic>> getDailyHoroscope(String sunSign) async {
    final normalized = sunSign.trim();
    if (normalized.isEmpty) {
      throw Exception('Sun sign is required for horoscope');
    }
    final response = await _client.get(
      ApiConfig.predictionDailyHoroscope,
      queryParameters: <String, dynamic>{'sunSign': normalized},
    );
    return _toMap(response.data);
  }

  Future<Map<String, dynamic>> getTodayPanchang(int userId) async {
    final response = await _client.get(
      ApiConfig.getTodayPanchang,
      queryParameters: <String, dynamic>{'userId': userId},
    );
    return _toMap(response.data);
  }

  Future<Map<String, dynamic>> generateKundliFromProfile({
    required int userId,
    required Map<String, dynamic> profileResponse,
  }) async {
    final payload = _payload(profileResponse);
    final dateOfBirth = _normalizeDate(
      _pickFirstString(payload, const <String>[
        'dateOfBirth',
        'dob',
        'birthDate',
      ]),
    );
    final birthTime = _normalizeTime(
      _pickFirstString(payload, const <String>[
        'birthTime',
        'timeOfBirth',
        'time_of_birth',
      ]),
      amPm: _pickFirstString(payload, const <String>['birthAmPm', 'amPm']),
    );

    if (dateOfBirth == null || birthTime == null) {
      throw Exception('Date of birth or birth time missing');
    }

    final request = <String, dynamic>{
      'userId': userId,
      'dateOfBirth': dateOfBirth,
      'timeOfBirth': birthTime,
    };

    final name = _pickFirstString(payload, const <String>[
      'name',
      'fullName',
      'userName',
    ]);
    if (name != null) {
      request['name'] = name;
    }

    final latitude = _pickFirstDouble(payload, const <String>[
      'latitude',
      'mobileLatitude',
      'lat',
    ]);
    if (latitude != null) {
      request['latitude'] = latitude;
    }

    final longitude = _pickFirstDouble(payload, const <String>[
      'longitude',
      'mobileLongitude',
      'lon',
      'lng',
    ]);
    if (longitude != null) {
      request['longitude'] = longitude;
    }

    final timezone = _pickFirstString(payload, const <String>[
      'timezone',
      'timeZone',
    ]);
    if (timezone != null) {
      request['timezone'] = timezone;
    }

    debugPrint('[AdminUserAstro] Kundli request payload: $request');
    final response = await _client.post(
      ApiConfig.fullKundliCalculate,
      data: request,
    );
    return _toMap(response.data);
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw Exception('Invalid server response format');
  }

  Map<String, dynamic> _payload(Map<String, dynamic> source) {
    final data = source['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return source;
  }

  String? _pickFirstString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) {
        continue;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  double? _pickFirstDouble(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) {
        continue;
      }
      if (value is num) {
        return value.toDouble();
      }
      final parsed = double.tryParse(value.toString().trim());
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  String? _normalizeDate(String? raw) {
    if (raw == null) {
      return null;
    }
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }

    final dmy = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$');
    final ymd = RegExp(r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})$');

    final dmyMatch = dmy.firstMatch(value);
    if (dmyMatch != null) {
      final day = dmyMatch.group(1)!.padLeft(2, '0');
      final month = dmyMatch.group(2)!.padLeft(2, '0');
      final year = dmyMatch.group(3)!;
      return '$year-$month-$day';
    }

    final ymdMatch = ymd.firstMatch(value);
    if (ymdMatch != null) {
      final year = ymdMatch.group(1)!;
      final month = ymdMatch.group(2)!.padLeft(2, '0');
      final day = ymdMatch.group(3)!.padLeft(2, '0');
      return '$year-$month-$day';
    }

    return value;
  }

  String? _normalizeTime(String? raw, {String? amPm}) {
    if (raw == null) {
      return null;
    }
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }

    final upper = value.toUpperCase();
    if (upper.endsWith('AM') || upper.endsWith('PM')) {
      return value;
    }

    final suffix = amPm?.trim().toUpperCase() ?? '';
    if (suffix == 'AM' || suffix == 'PM') {
      return '$value $suffix';
    }
    return value;
  }
}
