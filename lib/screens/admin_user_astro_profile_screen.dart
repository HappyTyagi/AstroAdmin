import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart' as html;
import 'package:flutter_html_svg/flutter_html_svg.dart';
import 'package:intl/intl.dart';

import '../services/admin_user_astro_service.dart';
import '../services/app_preferences.dart';
import '../theme/app_theme.dart';

class _AdminKundliChartEntry {
  const _AdminKundliChartEntry({
    required this.label,
    required this.icon,
    required this.previewText,
    this.htmlContent,
  });

  final String label;
  final IconData icon;
  final String previewText;
  final String? htmlContent;

  bool get hasHtml => htmlContent != null && htmlContent!.trim().isNotEmpty;
}

class AdminUserAstroProfileScreen extends StatefulWidget {
  const AdminUserAstroProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userPhone,
    this.userAvatar,
  });

  final int userId;
  final String userName;
  final String? userPhone;
  final String? userAvatar;

  @override
  State<AdminUserAstroProfileScreen> createState() =>
      _AdminUserAstroProfileScreenState();
}

class _AdminUserAstroProfileScreenState
    extends State<AdminUserAstroProfileScreen> {
  final AdminUserAstroService _service = AdminUserAstroService();

  static const Map<int, int> _rahuKaalSegmentByWeekday = <int, int>{
    DateTime.monday: 2,
    DateTime.tuesday: 7,
    DateTime.wednesday: 5,
    DateTime.thursday: 6,
    DateTime.friday: 4,
    DateTime.saturday: 3,
    DateTime.sunday: 8,
  };

  static const Map<String, int> _weekdayLookup = <String, int>{
    'monday': DateTime.monday,
    'mon': DateTime.monday,
    'सोमवार': DateTime.monday,
    'सोम': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'tue': DateTime.tuesday,
    'tues': DateTime.tuesday,
    'मंगलवार': DateTime.tuesday,
    'मंगल': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'wed': DateTime.wednesday,
    'बुधवार': DateTime.wednesday,
    'बुध': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'thu': DateTime.thursday,
    'thur': DateTime.thursday,
    'thurs': DateTime.thursday,
    'गुरुवार': DateTime.thursday,
    'गुरु': DateTime.thursday,
    'friday': DateTime.friday,
    'fri': DateTime.friday,
    'शुक्रवार': DateTime.friday,
    'शुक्र': DateTime.friday,
    'saturday': DateTime.saturday,
    'sat': DateTime.saturday,
    'शनिवार': DateTime.saturday,
    'शनि': DateTime.saturday,
    'sunday': DateTime.sunday,
    'sun': DateTime.sunday,
    'रविवार': DateTime.sunday,
    'रवि': DateTime.sunday,
  };

  bool _isHindi = AppPreferences.isHindiNotifier.value;
  bool _loading = true;
  String? _error;
  List<String> _warnings = <String>[];
  String? _kundliHint;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _dashboard;
  Map<String, dynamic>? _dailyHoroscope;
  Map<String, dynamic>? _kundli;
  Map<String, dynamic>? _panchang;

  @override
  void initState() {
    super.initState();
    AppPreferences.isHindiNotifier.addListener(_onLanguageChanged);
    _loadData();
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

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _warnings = <String>[];
      _kundliHint = null;
      _profile = null;
      _dashboard = null;
      _dailyHoroscope = null;
      _kundli = null;
      _panchang = null;
    });

    final List<String> warnings = <String>[];
    Map<String, dynamic>? profile;
    Map<String, dynamic>? dashboard;
    Map<String, dynamic>? horoscope;
    Map<String, dynamic>? kundli;
    Map<String, dynamic>? panchang;
    String? kundliHint;

    try {
      profile = await _service.getUserProfile(widget.userId);
    } catch (error) {
      warnings.add(_tr('Profile not loaded', 'प्रोफाइल लोड नहीं हुई'));
      debugPrint('[AdminUserAstro] profile error: $error');
    }

    final mobile = (widget.userPhone ?? '').trim();
    if (mobile.isNotEmpty) {
      try {
        dashboard = await _service.getDashboardByMobile(mobile);
      } catch (error) {
        warnings.add(_tr('Rashi data not loaded', 'राशि डेटा लोड नहीं हुआ'));
        debugPrint('[AdminUserAstro] dashboard error: $error');
      }
    } else {
      warnings.add(
        _tr('User mobile not available', 'यूज़र मोबाइल उपलब्ध नहीं है'),
      );
    }

    final dashboardData = _payload(dashboard);
    final sunSign = _pickFirstString(dashboardData, const <String>[
      'sunSign',
      'sun_sign',
      'suryaSign',
      'sunSignName',
    ]);
    if (sunSign != null) {
      try {
        horoscope = await _service.getDailyHoroscope(sunSign);
      } catch (error) {
        warnings.add(_tr('Rashifal not loaded', 'राशिफल लोड नहीं हुआ'));
        debugPrint('[AdminUserAstro] horoscope error: $error');
      }
    }

    try {
      panchang = await _service.getTodayPanchang(widget.userId);
    } catch (error) {
      warnings.add(_tr('Panchang not loaded', 'पंचांग लोड नहीं हुआ'));
      debugPrint('[AdminUserAstro] panchang error: $error');
    }

    if (profile != null) {
      try {
        kundli = await _service.generateKundliFromProfile(
          userId: widget.userId,
          profileResponse: profile,
        );
      } catch (error) {
        kundliHint = _tr(
          'Kundli needs date of birth and birth time.',
          'कुंडली के लिए जन्म तिथि और जन्म समय आवश्यक है।',
        );
        warnings.add(_tr('Kundli not generated', 'कुंडली जनरेट नहीं हुई'));
        debugPrint('[AdminUserAstro] kundli error: $error');
      }
    }

    final bool hasAnyData =
        profile != null ||
        dashboard != null ||
        horoscope != null ||
        kundli != null ||
        panchang != null;

    if (!mounted) return;
    setState(() {
      _loading = false;
      _profile = profile;
      _dashboard = dashboard;
      _dailyHoroscope = horoscope;
      _kundli = kundli;
      _panchang = panchang;
      _warnings = warnings;
      _kundliHint = kundliHint;
      _error = hasAnyData
          ? null
          : _tr(
              'Unable to load user insights right now.',
              'अभी यूज़र इनसाइट लोड नहीं हो पा रही है।',
            );
    });
  }

  Map<String, dynamic> _payload(Map<String, dynamic>? source) {
    if (source == null) {
      return <String, dynamic>{};
    }
    final dynamic data = source['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return source;
  }

  Map<String, dynamic>? _asMap(dynamic source) {
    if (source is Map<String, dynamic>) {
      return source;
    }
    if (source is Map) {
      return Map<String, dynamic>.from(source);
    }
    if (source is String) {
      final trimmed = source.trim();
      if (trimmed.isEmpty ||
          (!trimmed.startsWith('{') && !trimmed.startsWith('['))) {
        return null;
      }
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return null;
  }

  List<Map<String, dynamic>> _asMapList(dynamic source) {
    if (source is List) {
      return source
          .map((item) => _asMap(item))
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }
    final decodedList = _decodeJsonList(source);
    if (decodedList != null) {
      return decodedList
          .map((item) => _asMap(item))
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  List<dynamic>? _decodeJsonList(dynamic source) {
    if (source is List) {
      return source;
    }
    if (source is! String) {
      return null;
    }
    final trimmed = source.trim();
    if (!trimmed.startsWith('[')) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  String? _pickFirstString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty || text.toLowerCase() == 'null') continue;
      return text;
    }
    return null;
  }

  dynamic _pickFirstDynamic(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      if (!source.containsKey(key)) continue;
      final value = source[key];
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      return value;
    }
    return null;
  }

  String _formatValue(dynamic value) {
    if (value == null) return '--';
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final direct = _pickFirstString(map, const <String>[
        'name',
        'value',
        'title',
        'display',
        'displayName',
        'text',
      ]);
      if (direct != null) {
        return direct;
      }
      final nestedValues = map.values
          .map<String>(_formatValue)
          .where((item) => item != '--')
          .toList();
      if (nestedValues.isNotEmpty) {
        return nestedValues.join(' • ');
      }
      return '--';
    }
    if (value is List) {
      final text = value
          .map<String>(_formatValue)
          .where((item) => item != '--')
          .join(', ');
      return text.isEmpty ? '--' : text;
    }
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '--';
    }
    return text;
  }

  String _humanizeKey(String key) {
    final spaced = key
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (m) => '${m.group(1)} ${m.group(2)}',
        )
        .replaceAll('_', ' ')
        .trim();
    if (spaced.isEmpty) {
      return key;
    }
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  String _formatStructuredValue(dynamic value) {
    if (value == null) return '--';
    final decodedMap = _asMap(value);
    if (decodedMap != null) {
      if (decodedMap.isEmpty) return '--';
      final nestedText = _pickFirstString(decodedMap, const <String>[
        'text',
        'message',
        'description',
        'value',
        'content',
        'prediction',
      ]);
      if (nestedText != null) {
        return nestedText;
      }
      final lines = <String>[];
      for (final entry in decodedMap.entries) {
        final formatted = _formatStructuredValue(entry.value);
        if (formatted == '--') continue;
        lines.add('${_humanizeKey(entry.key)}: $formatted');
      }
      return lines.isEmpty ? '--' : lines.join('\n');
    }

    final decodedList = _decodeJsonList(value);
    if (decodedList != null) {
      final lines = decodedList
          .map(_formatStructuredValue)
          .where((item) => item != '--')
          .toList();
      return lines.isEmpty ? '--' : lines.join('\n');
    }

    if (value is List) {
      final lines = value
          .map(_formatStructuredValue)
          .where((item) => item != '--')
          .toList();
      return lines.isEmpty ? '--' : lines.join('\n');
    }

    final raw = value.toString().trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') {
      return '--';
    }

    final decoded = _asMap(raw);
    if (decoded != null) {
      return _formatStructuredValue(decoded);
    }
    return raw;
  }

  String _combineBirthTime(Map<String, dynamic> profileData) {
    final base = _pickFirstString(profileData, const <String>[
      'birthTime',
      'timeOfBirth',
    ]);
    final amPm = _pickFirstString(profileData, const <String>[
      'birthAmPm',
      'amPm',
    ]);
    if (base == null) {
      return '--';
    }
    final upper = base.toUpperCase();
    if (upper.endsWith('AM') || upper.endsWith('PM') || amPm == null) {
      return base;
    }
    return '$base ${amPm.toUpperCase()}';
  }

  Map<String, dynamic> _extractHoroscopeSections(
    Map<String, dynamic>? response,
  ) {
    final root = response ?? <String, dynamic>{};
    final nestedPayload =
        _asMap(root['horoscope']) ??
        _asMap(root['data']) ??
        _asMap(root['prediction']) ??
        _asMap(root['predictions']) ??
        _payload(response);

    final List<Map<String, dynamic>> predictionItems = _asMapList(
      nestedPayload['predictions'],
    );
    final Map<String, dynamic> firstPrediction = predictionItems.isNotEmpty
        ? predictionItems.first
        : <String, dynamic>{};

    String pickLocalized(
      Map<String, dynamic> source, {
      required List<String> englishKeys,
      required List<String> hindiKeys,
      List<String> fallbackKeys = const <String>[],
    }) {
      final primary = _isHindi
          ? <String>[...hindiKeys, ...englishKeys]
          : <String>[...englishKeys, ...hindiKeys];

      final dynamic fromPrimary = _pickFirstDynamic(source, primary);
      final String formattedPrimary = _formatStructuredValue(fromPrimary);
      if (formattedPrimary != '--') {
        return formattedPrimary;
      }

      final dynamic fromFallback = _pickFirstDynamic(source, fallbackKeys);
      final String formattedFallback = _formatStructuredValue(fromFallback);
      if (formattedFallback != '--') {
        return formattedFallback;
      }

      final dynamic fromItem = _pickFirstDynamic(firstPrediction, primary);
      final String formattedItem = _formatStructuredValue(fromItem);
      if (formattedItem != '--') {
        return formattedItem;
      }

      final dynamic fromItemFallback = _pickFirstDynamic(
        firstPrediction,
        fallbackKeys,
      );
      final String formattedItemFallback = _formatStructuredValue(
        fromItemFallback,
      );
      if (formattedItemFallback != '--') {
        return formattedItemFallback;
      }

      return '--';
    }

    final luckySource = _asMap(nestedPayload['lucky']) ?? <String, dynamic>{};
    final sign = pickLocalized(
      nestedPayload,
      englishKeys: const <String>['sign', 'rashi', 'sunSign', 'moonSign'],
      hindiKeys: const <String>['signHindi', 'signHi', 'rashiHindi', 'rashiHi'],
    );

    return <String, dynamic>{
      'sign': sign,
      'date': _formatStructuredValue(
        nestedPayload['date'] ??
            nestedPayload['predictionDate'] ??
            DateFormat('yyyy-MM-dd').format(DateTime.now()),
      ),
      'overall': pickLocalized(
        nestedPayload,
        englishKeys: const <String>['overall', 'dailySummary', 'summary'],
        hindiKeys: const <String>[
          'overallHindi',
          'overallHi',
          'dailySummaryHindi',
          'dailySummaryHi',
        ],
      ),
      'love': pickLocalized(
        nestedPayload,
        englishKeys: const <String>['love', 'relationship'],
        hindiKeys: const <String>[
          'loveHindi',
          'loveHi',
          'relationshipHindi',
          'relationshipHi',
        ],
      ),
      'career': pickLocalized(
        nestedPayload,
        englishKeys: const <String>['career', 'work'],
        hindiKeys: const <String>[
          'careerHindi',
          'careerHi',
          'workHindi',
          'workHi',
        ],
      ),
      'finance': pickLocalized(
        nestedPayload,
        englishKeys: const <String>['finance', 'money'],
        hindiKeys: const <String>[
          'financeHindi',
          'financeHi',
          'moneyHindi',
          'moneyHi',
        ],
      ),
      'health': pickLocalized(
        nestedPayload,
        englishKeys: const <String>['health', 'wellness'],
        hindiKeys: const <String>[
          'healthHindi',
          'healthHi',
          'wellnessHindi',
          'wellnessHi',
        ],
      ),
      'advice': pickLocalized(
        nestedPayload,
        englishKeys: const <String>['advice', 'guidance'],
        hindiKeys: const <String>[
          'adviceHindi',
          'adviceHi',
          'guidanceHindi',
          'guidanceHi',
        ],
      ),
      'lucky': <String, String>{
        'number': _formatStructuredValue(
          luckySource['number'] ?? luckySource['luckyNumber'],
        ),
        'color': pickLocalized(
          luckySource,
          englishKeys: const <String>['color', 'luckyColor'],
          hindiKeys: const <String>['colorHindi', 'colorHi'],
        ),
        'time': pickLocalized(
          luckySource,
          englishKeys: const <String>['time', 'luckyTime'],
          hindiKeys: const <String>['timeHindi', 'timeHi'],
        ),
        'direction': pickLocalized(
          luckySource,
          englishKeys: const <String>['direction', 'luckyDirection'],
          hindiKeys: const <String>['directionHindi', 'directionHi'],
        ),
      },
    };
  }

  String _toBulletLines(dynamic value) {
    final formatted = _formatStructuredValue(value);
    if (formatted == '--') {
      return '--';
    }
    final lines = formatted
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return '--';
    }
    return lines.map((line) => '• $line').join('\n');
  }

  int? _resolveWeekday(Map<String, dynamic> source) {
    final dateText = _pickFirstString(source, const <String>[
      'dayOfWeek',
      'vara',
      'weekday',
      'day',
    ]);
    if (dateText != null) {
      final normalized = dateText.toLowerCase().trim();
      final fromLookup = _weekdayLookup[normalized];
      if (fromLookup != null) {
        return fromLookup;
      }
    }

    final dateRaw = _pickFirstString(source, const <String>[
      'dateTime',
      'date',
    ]);
    if (dateRaw == null) return null;
    final parsed = DateTime.tryParse(dateRaw);
    return parsed?.weekday;
  }

  DateTime? _parseClockTime(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty || value == '--') return null;
    final RegExp pattern = RegExp(
      r'^(\d{1,2})[:.](\d{2})(?:[:.](\d{2}))?\s*([AaPp][Mm])?$',
    );
    final match = pattern.firstMatch(value);
    if (match == null) return null;
    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    final second = int.tryParse(match.group(3) ?? '0') ?? 0;
    if (hour == null || minute == null) return null;

    final marker = (match.group(4) ?? '').toUpperCase();
    if (marker == 'PM' && hour < 12) {
      hour += 12;
    } else if (marker == 'AM' && hour == 12) {
      hour = 0;
    }

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute, second);
  }

  String _formatClockTime(DateTime value) {
    return DateFormat('hh:mm a').format(value);
  }

  String _resolveRahuKaal(Map<String, dynamic> source) {
    final directStart = _formatValue(
      source['rahuKaalStart'] ??
          source['rahuKalamStart'] ??
          source['rahu_start'] ??
          source['rahukaalStart'],
    );
    final directEnd = _formatValue(
      source['rahuKaalEnd'] ??
          source['rahuKalamEnd'] ??
          source['rahu_end'] ??
          source['rahukaalEnd'],
    );
    if (directStart != '--' && directEnd != '--') {
      return '$directStart - $directEnd';
    }

    final direct = _formatValue(
      source['rahuKaal'] ??
          source['rahukaal'] ??
          source['rahuKalam'] ??
          source['rahuKaalTime'],
    );
    if (direct != '--') {
      return direct;
    }

    final sunrise = _parseClockTime(
      _pickFirstString(source, const <String>['sunrise', 'sunRise']),
    );
    final sunset = _parseClockTime(
      _pickFirstString(source, const <String>['sunset', 'sunSet']),
    );
    final weekday = _resolveWeekday(source);

    if (sunrise == null || sunset == null || weekday == null) {
      return '--';
    }

    final segment = _rahuKaalSegmentByWeekday[weekday];
    if (segment == null) return '--';

    final dayDuration = sunset.difference(sunrise);
    if (dayDuration.inMinutes <= 0) return '--';

    final segmentDuration = Duration(
      minutes: (dayDuration.inMinutes / 8).round(),
    );
    final start = sunrise.add(segmentDuration * (segment - 1));
    final end = start.add(segmentDuration);
    return '${_formatClockTime(start)} - ${_formatClockTime(end)}';
  }

  String _formatDoshaValue(dynamic source) {
    if (source == null) {
      return _tr('Not Present', 'मौजूद नहीं');
    }
    final dosha = _asMap(source);
    if (dosha == null) {
      return _formatStructuredValue(source);
    }
    final present = dosha['present'];
    final String status;
    if (present is bool) {
      status = present
          ? _tr('Present', 'मौजूद')
          : _tr('Not Present', 'मौजूद नहीं');
    } else {
      status = _tr('Unknown', 'अज्ञात');
    }
    final description = _formatStructuredValue(
      dosha['description'] ?? dosha['details'],
    );
    final remedy = _formatStructuredValue(
      dosha['remedyAdvice'] ?? dosha['remedy'],
    );
    final parts = <String>[status];
    if (description != '--') {
      parts.add(description);
    }
    if (remedy != '--') {
      parts.add('${_tr('Remedy', 'उपाय')}: $remedy');
    }
    return parts.join(' • ');
  }

  String _normalizeLookupKey(String key) {
    return key.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  dynamic _lookupFlexibleValue(Map<String, dynamic>? map, String key) {
    if (map == null || map.isEmpty) {
      return null;
    }
    if (map.containsKey(key)) {
      return map[key];
    }
    final String normalizedKey = _normalizeLookupKey(key);
    if (normalizedKey.isEmpty) {
      return null;
    }
    for (final MapEntry<String, dynamic> entry in map.entries) {
      if (_normalizeLookupKey(entry.key) == normalizedKey) {
        return entry.value;
      }
    }
    return null;
  }

  dynamic _resolveKundliValue(
    Map<String, dynamic> source,
    List<String> keys, {
    List<String> nestedContainers = const <String>[],
  }) {
    for (final String key in keys) {
      final dynamic value = _lookupFlexibleValue(source, key);
      if (value != null) {
        return value;
      }
    }
    for (final String container in nestedContainers) {
      final Map<String, dynamic>? nested = _asMap(
        _lookupFlexibleValue(source, container),
      );
      if (nested == null || nested.isEmpty) {
        continue;
      }
      for (final String key in keys) {
        final dynamic value = _lookupFlexibleValue(nested, key);
        if (value != null) {
          return value;
        }
      }
    }
    return null;
  }

  List<String> _resolveKundliList(
    Map<String, dynamic> source,
    List<String> keys, {
    List<String> nestedContainers = const <String>[],
  }) {
    dynamic pickFrom(Map<String, dynamic> map) {
      for (final String key in keys) {
        final dynamic value = _lookupFlexibleValue(map, key);
        if (value != null) {
          return value;
        }
      }
      return null;
    }

    dynamic picked = pickFrom(source);
    if (picked == null) {
      for (final String container in nestedContainers) {
        final Map<String, dynamic>? nested = _asMap(
          _lookupFlexibleValue(source, container),
        );
        if (nested == null || nested.isEmpty) {
          continue;
        }
        picked = pickFrom(nested);
        if (picked != null) {
          break;
        }
      }
    }

    if (picked == null) {
      return const <String>[];
    }
    if (picked is List) {
      return picked
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (picked is String) {
      final String raw = picked.trim();
      if (raw.isEmpty || raw.toLowerCase() == 'null') {
        return const <String>[];
      }
      if (raw.startsWith('[')) {
        final List<dynamic>? decoded = _decodeJsonList(raw);
        if (decoded != null) {
          return decoded
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false);
        }
      }
      if (raw.contains(',')) {
        return raw
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      return <String>[raw];
    }
    return <String>[picked.toString()];
  }

  double? _asDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    final String normalized = value.toString().trim();
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  Map<String, double>? _extractElementValues(Map<String, dynamic> source) {
    final Map<String, double> normalized = <String, double>{};

    void assign(String canonical, dynamic rawValue) {
      final double? parsed = _asDouble(rawValue);
      if (parsed != null) {
        normalized[canonical] = parsed;
      }
    }

    for (final MapEntry<String, dynamic> entry in source.entries) {
      final String rawKey = entry.key.trim().toLowerCase();
      if (rawKey.isEmpty) {
        continue;
      }
      if (entry.value is Map || entry.value is List) {
        continue;
      }

      if (rawKey.contains('fire') || rawKey.contains('agni')) {
        assign('Fire', entry.value);
      } else if (rawKey.contains('earth') ||
          rawKey.contains('prith') ||
          rawKey.contains('bhumi')) {
        assign('Earth', entry.value);
      } else if (rawKey.contains('air') || rawKey.contains('vayu')) {
        assign('Air', entry.value);
      } else if (rawKey.contains('water') || rawKey.contains('jal')) {
        assign('Water', entry.value);
      }
    }
    return normalized.isEmpty ? null : normalized;
  }

  double? _extractElementsAverage(Map<String, dynamic> source) {
    for (final String key in const <String>[
      'average',
      'Average',
      'mean',
      'avg',
      'elementsAverage',
      'overallAverage',
    ]) {
      final double? parsed = _asDouble(source[key]);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  double _calculateElementsAverage(Map<String, double> elements) {
    if (elements.isEmpty) {
      return 0;
    }
    final double sum = elements.values.fold<double>(
      0,
      (double prev, double item) => prev + item,
    );
    return sum / elements.length;
  }

  ({Map<String, double> elements, double average})?
  _resolvePredominantElementsData(Map<String, dynamic> kundliData) {
    final Map<String, dynamic>? elementsRoot =
        _asMap(kundliData['elements']) ??
        _asMap(_asMap(kundliData['predominantElements'])?['values']) ??
        _asMap(kundliData['predominantElements']) ??
        _asMap(kundliData['elementBalance']);
    if (elementsRoot == null || elementsRoot.isEmpty) {
      return null;
    }

    Map<String, double>? elements = _extractElementValues(elementsRoot);
    if (elements == null || elements.isEmpty) {
      for (final dynamic candidate in <dynamic>[
        elementsRoot['Average'],
        elementsRoot['average'],
        elementsRoot['averageValues'],
        elementsRoot['elementValues'],
        elementsRoot['values'],
      ]) {
        final Map<String, dynamic>? nested = _asMap(candidate);
        if (nested == null || nested.isEmpty) {
          continue;
        }
        elements = _extractElementValues(nested);
        if (elements != null && elements.isNotEmpty) {
          break;
        }
      }
    }
    if (elements == null || elements.isEmpty) {
      return null;
    }

    final double average =
        _extractElementsAverage(elementsRoot) ??
        _calculateElementsAverage(elements);
    return (elements: elements, average: average);
  }

  String _elementLabel(String key) {
    switch (key.trim().toLowerCase()) {
      case 'fire':
        return _tr('Fire', 'अग्नि');
      case 'earth':
        return _tr('Earth', 'पृथ्वी');
      case 'air':
        return _tr('Air', 'वायु');
      case 'water':
        return _tr('Water', 'जल');
      default:
        return _humanizeKey(key);
    }
  }

  String _chartPreviewText(dynamic source) {
    if (source == null) {
      return '--';
    }
    final String? htmlContent = _extractHtmlContent(source);
    if (htmlContent != null) {
      final String plain = htmlContent
          .replaceAll(
            RegExp(
              r'<style.*?>.*?</style>',
              dotAll: true,
              caseSensitive: false,
            ),
            ' ',
          )
          .replaceAll(
            RegExp(
              r'<script.*?>.*?</script>',
              dotAll: true,
              caseSensitive: false,
            ),
            ' ',
          )
          .replaceAll(
            RegExp(r'<[^>]+>', dotAll: true, caseSensitive: false),
            ' ',
          )
          .replaceAll('&nbsp;', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (plain.isEmpty) {
        return _tr(
          'Chart generated successfully. HTML visualization is available.',
          'चार्ट सफलतापूर्वक जनरेट हुआ। HTML विज़ुअल उपलब्ध है।',
        );
      }
      if (plain.length > 360) {
        return '${plain.substring(0, 360)}...';
      }
      return plain;
    }

    final String formatted = _formatStructuredValue(source);
    if (formatted == '--') {
      return '--';
    }
    if (formatted.length > 360) {
      return '${formatted.substring(0, 360)}...';
    }
    return formatted;
  }

  String _decodeHtmlEntities(String raw) {
    return raw
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  bool _looksLikeHtml(String raw) {
    final String value = raw.trim().toLowerCase();
    if (value.isEmpty) return false;
    return RegExp(
      r'<\s*(html|body|table|tr|td|th|div|span|svg|img|style|h[1-6]|p|ul|ol|li)\b',
      caseSensitive: false,
    ).hasMatch(value);
  }

  String _normalizeKundliHtml(String rawHtml) {
    final String styles =
        RegExp(
          r'<style[^>]*>([\s\S]*?)</style>',
          caseSensitive: false,
        ).allMatches(rawHtml).map((m) => m.group(1) ?? '').join('\n');
    final Match? bodyMatch = RegExp(
      r'<body[^>]*>([\s\S]*?)</body>',
      caseSensitive: false,
    ).firstMatch(rawHtml);
    final String body = bodyMatch?.group(1) ?? rawHtml;

    const String forceFullWidthStyle = '''
<style>
html, body {
  margin: 0 !important;
  padding: 0 !important;
  width: 100% !important;
  overflow-x: hidden !important;
}
* { box-sizing: border-box; }
svg, img, table {
  width: 100% !important;
  max-width: 100% !important;
  height: auto !important;
}
</style>
''';
    final String styleBlock = styles.trim().isEmpty
        ? ''
        : '<style>$styles</style>';
    return '$forceFullWidthStyle$styleBlock$body';
  }

  String? _extractHtmlContent(dynamic source, {int depth = 0}) {
    if (source == null || depth > 5) {
      return null;
    }

    if (source is String) {
      String raw = source.trim();
      if (raw.isEmpty || raw.toLowerCase() == 'null') {
        return null;
      }

      if (raw.startsWith('{') || raw.startsWith('[')) {
        try {
          final dynamic decoded = jsonDecode(raw);
          return _extractHtmlContent(decoded, depth: depth + 1);
        } catch (_) {}
      }

      if ((raw.startsWith('"') && raw.endsWith('"')) ||
          (raw.startsWith("'") && raw.endsWith("'"))) {
        try {
          final dynamic decoded = jsonDecode(raw);
          if (decoded is String) {
            raw = decoded.trim();
          }
        } catch (_) {}
      }

      final String normalized = _decodeHtmlEntities(
        raw
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\t', ' ')
            .replaceAll(r'\"', '"'),
      ).trim();
      if (_looksLikeHtml(normalized)) {
        return _normalizeKundliHtml(normalized);
      }
      return null;
    }

    if (source is Map || source is List) {
      final Map<String, dynamic>? map = _asMap(source);
      if (map != null) {
        for (final String key in const <String>[
          'html',
          'htmlContent',
          'content',
          'chartHtml',
          'reportHtml',
          'value',
          'data',
          'htmlSections',
        ]) {
          final String? found = _extractHtmlContent(
            _lookupFlexibleValue(map, key),
            depth: depth + 1,
          );
          if (found != null) {
            return found;
          }
        }
        for (final MapEntry<String, dynamic> entry in map.entries) {
          final String? found = _extractHtmlContent(
            entry.value,
            depth: depth + 1,
          );
          if (found != null) {
            return found;
          }
        }
        return null;
      }

      if (source is List) {
        for (final dynamic item in source) {
          final String? found = _extractHtmlContent(item, depth: depth + 1);
          if (found != null) {
            return found;
          }
        }
      }
    }

    return null;
  }

  dynamic _pickChartSource({
    required Map<String, dynamic> kundliData,
    required Map<String, dynamic> planetary,
    required Map<String, dynamic> htmlSections,
    required List<String> keys,
  }) {
    dynamic pickFrom(Map<String, dynamic>? source) {
      if (source == null || source.isEmpty) {
        return null;
      }
      for (final String key in keys) {
        final dynamic value = _lookupFlexibleValue(source, key);
        if (value != null) {
          return value;
        }
      }
      return null;
    }

    final dynamic fromHtmlSections = pickFrom(htmlSections);
    if (fromHtmlSections != null) {
      return fromHtmlSections;
    }

    final dynamic fromPlanetary = pickFrom(planetary);
    if (fromPlanetary != null) {
      return fromPlanetary;
    }

    final dynamic fromRoot = pickFrom(kundliData);
    if (fromRoot != null) {
      return fromRoot;
    }

    for (final String container in const <String>[
      'charts',
      'chartData',
      'kundliCharts',
      'htmlSections',
      'report',
      'response',
      'result',
    ]) {
      final Map<String, dynamic>? nested = _asMap(
        _lookupFlexibleValue(kundliData, container),
      );
      final dynamic nestedValue = pickFrom(nested);
      if (nestedValue != null) {
        return nestedValue;
      }
    }
    return null;
  }

  List<_AdminKundliChartEntry> _resolveChartEntries(
    Map<String, dynamic> kundliData,
  ) {
    final Map<String, dynamic> planetary =
        _asMap(kundliData['planetaryPositions']) ?? <String, dynamic>{};
    final Map<String, dynamic> htmlSections =
        _asMap(planetary['htmlSections']) ?? <String, dynamic>{};

    final List<({String label, List<String> keys, IconData icon})> sources =
        <({String label, List<String> keys, IconData icon})>[
          (
            label: _tr('Birth Chart', 'जन्म कुंडली'),
            keys: const <String>[
              'kundliChart',
              'birthChart',
              'birth_chart',
              'lagnaChart',
              'lagnaKundli',
            ],
            icon: Icons.home_work_outlined,
          ),
          (
            label: _tr('Navamsha Chart', 'नवांश कुंडली'),
            keys: const <String>[
              'navamshaChart',
              'navamsaChart',
              'navamsha_chart',
              'd9Chart',
            ],
            icon: Icons.stars_rounded,
          ),
          (
            label: _tr('Transit Chart', 'गोचर कुंडली'),
            keys: const <String>[
              'transitChart',
              'transit_chart',
              'gocharChart',
              'gocharKundli',
            ],
            icon: Icons.travel_explore_rounded,
          ),
          (
            label: _tr('Planetary Positions', 'ग्रह स्थिति'),
            keys: const <String>[
              'planetaryPositions',
              'planetaryPosition',
              'planetPositions',
              'grahSthiti',
              'htmlContent',
            ],
            icon: Icons.public_rounded,
          ),
        ];

    final List<_AdminKundliChartEntry> output = <_AdminKundliChartEntry>[];
    for (final source in sources) {
      final dynamic rawData = _pickChartSource(
        kundliData: kundliData,
        planetary: planetary,
        htmlSections: htmlSections,
        keys: source.keys,
      );
      final String? htmlContent = _extractHtmlContent(rawData);
      final String preview = _chartPreviewText(rawData);
      if (htmlContent == null && preview == '--') {
        continue;
      }
      output.add(
        _AdminKundliChartEntry(
          label: source.label,
          icon: source.icon,
          previewText: preview,
          htmlContent: htmlContent,
        ),
      );
    }
    return output;
  }

  Widget _buildInfoTile({
    required bool isDark,
    required String label,
    required String value,
    IconData? icon,
  }) {
    final textColor = isDark ? Colors.white : AdminAppTheme.ink;
    final muted = isDark ? Colors.white70 : AdminAppTheme.muted;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1F2B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AdminAppTheme.royal.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: AdminAppTheme.gold),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHtmlChartTile({
    required bool isDark,
    required _AdminKundliChartEntry entry,
  }) {
    final Color textColor = isDark ? Colors.white : AdminAppTheme.ink;
    final Color muted = isDark ? Colors.white70 : AdminAppTheme.muted;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1F2B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AdminAppTheme.royal.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(entry.icon, size: 16, color: AdminAppTheme.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
              ),
            ],
          ),
          if (entry.previewText != '--') ...<Widget>[
            const SizedBox(height: 6),
            Text(
              entry.previewText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: isDark ? const Color(0xFF0F1219) : const Color(0xFFFAFBFF),
              child: html.Html(
                data: entry.htmlContent ?? '',
                extensions: const [SvgHtmlExtension()],
                style: <String, html.Style>{
                  'html': html.Style(
                    margin: html.Margins.zero,
                    padding: html.HtmlPaddings.zero,
                    color: textColor,
                  ),
                  'body': html.Style(
                    margin: html.Margins.zero,
                    padding: html.HtmlPaddings.zero,
                    color: textColor,
                    backgroundColor: isDark
                        ? const Color(0xFF0F1219)
                        : const Color(0xFFFAFBFF),
                    fontSize: html.FontSize(13),
                  ),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required bool isDark,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171A24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AdminAppTheme.royal.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? AdminAppTheme.gold : AdminAppTheme.royal,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildUserAvatar() {
    final source = (widget.userAvatar ?? '').trim();
    if (source.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          source,
          width: 46,
          height: 46,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(),
        ),
      );
    }
    return _buildAvatarFallback();
  }

  Widget _buildAvatarFallback() {
    final trimmed = widget.userName.trim();
    final letter = trimmed.isEmpty
        ? 'U'
        : trimmed.substring(0, 1).toUpperCase();
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        color: AdminAppTheme.royal,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileData = _payload(_profile);
    final dashboardData = _payload(_dashboard);
    final phone =
        _pickFirstString(profileData, const <String>[
          'mobileNo',
          'mobileNumber',
          'phone',
        ]) ??
        (widget.userPhone ?? '--');
    final String headerAddress = <String>[
      _pickFirstString(profileData, const <String>[
            'address',
            'fullAddress',
            'currentAddress',
          ]) ??
          '',
      _pickFirstString(profileData, const <String>['city']) ?? '',
      _pickFirstString(profileData, const <String>['state']) ?? '',
    ].where((item) => item.trim().isNotEmpty && item.trim() != '--').join(', ');

    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('User Astro Insights', 'यूज़र एस्ट्रो इनसाइट्स')),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _loadData,
            tooltip: _tr('Refresh', 'रिफ्रेश'),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: AdminAppTheme.pageBackdrop(isDark: isDark),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _UserInsightState(
                icon: Icons.error_outline_rounded,
                title: _error!,
                subtitle: _tr(
                  'Please retry after some time.',
                  'कृपया कुछ समय बाद दोबारा प्रयास करें।',
                ),
                actionLabel: _tr('Retry', 'फिर से प्रयास करें'),
                onAction: _loadData,
              )
            : Column(
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF171A24) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AdminAppTheme.royal.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        _buildUserAvatar(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                widget.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AdminAppTheme.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white70
                                      : AdminAppTheme.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_tr('User ID', 'यूज़र आईडी')}: ${widget.userId}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white60
                                      : AdminAppTheme.muted,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_tr('Address', 'पता')}: ${headerAddress.isEmpty ? '--' : headerAddress}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? Colors.white60
                                      : AdminAppTheme.muted,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if ((dashboardData['sunSign'] ?? '')
                            .toString()
                            .isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AdminAppTheme.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formatValue(dashboardData['sunSign']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AdminAppTheme.royal,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_warnings.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.orange.withValues(alpha: 0.12)
                            : Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        _warnings.join(' • '),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.orange.shade200
                              : Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Expanded(
                    child: DefaultTabController(
                      length: 4,
                      child: Column(
                        children: <Widget>[
                          Container(
                            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF171A24)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: TabBar(
                              isScrollable: true,
                              indicatorColor: AdminAppTheme.gold,
                              labelColor: isDark
                                  ? AdminAppTheme.gold
                                  : AdminAppTheme.royal,
                              unselectedLabelColor: isDark
                                  ? Colors.white70
                                  : AdminAppTheme.muted,
                              labelStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              tabs: <Widget>[
                                Tab(text: _tr('Info', 'जानकारी')),
                                Tab(text: _tr('Rashifal', 'राशिफल')),
                                Tab(text: _tr('Kundli', 'कुंडली')),
                                Tab(text: _tr('Panchang', 'पंचांग')),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: <Widget>[
                                _buildInfoTab(isDark),
                                _buildRashifalTab(isDark),
                                _buildKundliTab(isDark),
                                _buildPanchangTab(isDark),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoTab(bool isDark) {
    final profileData = _payload(_profile);
    final dashboardData = _payload(_dashboard);
    final fullAddress =
        _pickFirstString(profileData, const <String>[
          'address',
          'fullAddress',
          'currentAddress',
        ]) ??
        '--';

    final city = _pickFirstString(profileData, const <String>['city']) ?? '';
    final state = _pickFirstString(profileData, const <String>['state']) ?? '';
    final address = [
      fullAddress,
      city,
      state,
    ].where((item) => item.isNotEmpty && item != '--').join(', ');

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: <Widget>[
          _buildSection(
            isDark: isDark,
            title: _tr('User Info', 'यूज़र जानकारी'),
            children: <Widget>[
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Name', 'नाम'),
                value:
                    _pickFirstString(profileData, const <String>['name']) ??
                    widget.userName,
                icon: Icons.person_outline_rounded,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Mobile', 'मोबाइल'),
                value:
                    _pickFirstString(profileData, const <String>[
                      'mobileNo',
                      'mobileNumber',
                      'phone',
                    ]) ??
                    (widget.userPhone ?? '--'),
                icon: Icons.phone_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Email', 'ईमेल'),
                value:
                    _pickFirstString(profileData, const <String>['email']) ??
                    '--',
                icon: Icons.email_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Date of Birth', 'जन्म तिथि'),
                value:
                    _pickFirstString(profileData, const <String>[
                      'dateOfBirth',
                      'dob',
                    ]) ??
                    '--',
                icon: Icons.calendar_month_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Birth Time', 'जन्म समय'),
                value: _combineBirthTime(profileData),
                icon: Icons.schedule_rounded,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Address', 'पता'),
                value: address.isEmpty ? '--' : address,
                icon: Icons.location_on_outlined,
              ),
            ],
          ),
          _buildSection(
            isDark: isDark,
            title: _tr('Rashi Snapshot', 'राशि स्नैपशॉट'),
            children: <Widget>[
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Sun Sign', 'सूर्य राशि'),
                value: _formatValue(
                  dashboardData['sunSign'] ?? dashboardData['suryaSign'],
                ),
                icon: Icons.wb_sunny_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Moon Sign', 'चंद्र राशि'),
                value: _formatValue(
                  dashboardData['moonSign'] ?? dashboardData['chandraSign'],
                ),
                icon: Icons.nightlight_round,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Lagna', 'लग्न'),
                value: _formatValue(dashboardData['lagnaSign']),
                icon: Icons.auto_awesome_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Nakshatra', 'नक्षत्र'),
                value: _formatValue(dashboardData['nakshatra']),
                icon: Icons.star_outline_rounded,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Good Time', 'शुभ समय'),
                value: _formatValue(dashboardData['auspiciousTime']),
                icon: Icons.timelapse_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRashifalTab(bool isDark) {
    final dashboardData = _payload(_dashboard);
    final parsed = _extractHoroscopeSections(_dailyHoroscope);
    final lucky = _asMap(parsed['lucky']) ?? <String, dynamic>{};
    final List<Map<String, dynamic>> sections = <Map<String, dynamic>>[
      <String, dynamic>{
        'label': _tr('Overall Outlook', 'समग्र दृष्टिकोण'),
        'icon': Icons.brightness_7_outlined,
        'value': parsed['overall'],
      },
      <String, dynamic>{
        'label': _tr('Love & Relationship', 'प्रेम और संबंध'),
        'icon': Icons.favorite_border_rounded,
        'value': parsed['love'],
      },
      <String, dynamic>{
        'label': _tr('Career', 'करियर'),
        'icon': Icons.work_outline_rounded,
        'value': parsed['career'],
      },
      <String, dynamic>{
        'label': _tr('Finance', 'वित्त'),
        'icon': Icons.account_balance_wallet_outlined,
        'value': parsed['finance'],
      },
      <String, dynamic>{
        'label': _tr('Health', 'स्वास्थ्य'),
        'icon': Icons.health_and_safety_outlined,
        'value': parsed['health'],
      },
      <String, dynamic>{
        'label': _tr('Guidance', 'मार्गदर्शन'),
        'icon': Icons.lightbulb_outline_rounded,
        'value': parsed['advice'],
      },
    ];

    final hasPrediction = sections.any(
      (section) => _formatStructuredValue(section['value']) != '--',
    );
    final hasLucky =
        _formatStructuredValue(lucky['number']) != '--' ||
        _formatStructuredValue(lucky['color']) != '--' ||
        _formatStructuredValue(lucky['time']) != '--' ||
        _formatStructuredValue(lucky['direction']) != '--';

    if (!hasPrediction && !hasLucky) {
      return _UserInsightState(
        icon: Icons.auto_graph_rounded,
        title: _tr('Rashifal unavailable', 'राशिफल उपलब्ध नहीं है'),
        subtitle: _tr(
          'Prediction response is empty for this user.',
          'इस यूज़र के लिए भविष्यफल डेटा उपलब्ध नहीं है।',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: <Widget>[
          _buildSection(
            isDark: isDark,
            title: _tr('Daily Rashifal', 'दैनिक राशिफल'),
            children: <Widget>[
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Rashi', 'राशि'),
                value: _formatValue(
                  parsed['sign'] ??
                      dashboardData['sunSign'] ??
                      dashboardData['moonSign'],
                ),
                icon: Icons.self_improvement_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Prediction Date', 'भविष्यफल की तारीख'),
                value: _formatValue(parsed['date']),
                icon: Icons.auto_graph_rounded,
              ),
              for (final section in sections)
                if (_formatStructuredValue(section['value']) != '--')
                  _buildInfoTile(
                    isDark: isDark,
                    label: section['label'].toString(),
                    value: _toBulletLines(section['value']),
                    icon: section['icon'] as IconData,
                  ),
            ],
          ),
          if (hasLucky)
            _buildSection(
              isDark: isDark,
              title: _tr('Lucky Details', 'शुभ विवरण'),
              children: <Widget>[
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Lucky Number', 'शुभ अंक'),
                  value: _formatStructuredValue(lucky['number']),
                  icon: Icons.filter_1_rounded,
                ),
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Lucky Color', 'शुभ रंग'),
                  value: _formatStructuredValue(lucky['color']),
                  icon: Icons.palette_outlined,
                ),
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Lucky Time', 'शुभ समय'),
                  value: _formatStructuredValue(lucky['time']),
                  icon: Icons.schedule_rounded,
                ),
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Lucky Direction', 'शुभ दिशा'),
                  value: _formatStructuredValue(lucky['direction']),
                  icon: Icons.explore_outlined,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildKundliTab(bool isDark) {
    final kundliData = _payload(_kundli);
    if (kundliData.isEmpty) {
      return _UserInsightState(
        icon: Icons.menu_book_outlined,
        title: _tr('Kundli unavailable', 'कुंडली उपलब्ध नहीं है'),
        subtitle:
            _kundliHint ??
            _tr(
              'User profile needs birth details for kundli.',
              'कुंडली के लिए यूज़र प्रोफाइल में जन्म विवरण चाहिए।',
            ),
      );
    }

    final panchangMap = _asMap(kundliData['panchang']) ?? <String, dynamic>{};
    final locationMeta =
        _asMap(kundliData['locationMeta']) ?? <String, dynamic>{};
    final dashaMap =
        _asMap(kundliData['vimshottariDasha']) ?? <String, dynamic>{};
    final predominantElementsData = _resolvePredominantElementsData(kundliData);
    final chartEntries = _resolveChartEntries(kundliData);
    final remediesMap = _asMap(kundliData['remedies']) ?? <String, dynamic>{};
    final planets = _asMapList(kundliData['planets']);
    final housesMap = _asMap(kundliData['houses']) ?? <String, dynamic>{};
    final List<String> auspiciousYogas = _resolveKundliList(
      kundliData,
      const <String>[
        'auspiciousYogas',
        'auspicious_yogas',
        'goodYogas',
        'positiveYogas',
        'yogas',
      ],
      nestedContainers: const <String>[
        'yoga',
        'yogas',
        'yogaDetails',
        'analysis',
      ],
    );
    final List<String> inauspiciousYogas = _resolveKundliList(
      kundliData,
      const <String>[
        'inauspiciousYogas',
        'inauspicious_yogas',
        'badYogas',
        'negativeYogas',
      ],
      nestedContainers: const <String>[
        'yoga',
        'yogas',
        'yogaDetails',
        'analysis',
      ],
    );
    final dynamic mangalDoshaValue = _resolveKundliValue(
      kundliData,
      const <String>[
        'mangalDosha',
        'mangal_dosha',
        'mangalikDosha',
        'manglikDosha',
      ],
      nestedContainers: const <String>[
        'doshaAnalysis',
        'doshas',
        'dosha',
        'dosh',
        'analysis',
      ],
    );
    final dynamic kaalSarpDoshaValue = _resolveKundliValue(
      kundliData,
      const <String>[
        'kaalSarpDosha',
        'kaal_sarp_dosha',
        'kaalSarpaDosha',
        'kalsarpDosha',
      ],
      nestedContainers: const <String>[
        'doshaAnalysis',
        'doshas',
        'dosha',
        'dosh',
        'analysis',
      ],
    );
    final dynamic pitruDoshaValue = _resolveKundliValue(
      kundliData,
      const <String>['pitruDosha', 'pitru_dosha', 'pitraDosha', 'pitrDosha'],
      nestedContainers: const <String>[
        'doshaAnalysis',
        'doshas',
        'dosha',
        'dosh',
        'analysis',
      ],
    );
    final dynamic grahanDoshaValue = _resolveKundliValue(
      kundliData,
      const <String>['grahanDosha', 'grahan_dosha', 'eclipseDosha'],
      nestedContainers: const <String>[
        'doshaAnalysis',
        'doshas',
        'dosha',
        'dosh',
        'analysis',
      ],
    );
    final dynamic nadiDoshaValue = _resolveKundliValue(
      kundliData,
      const <String>['nadiDosha', 'nadi_dosha'],
      nestedContainers: const <String>[
        'doshaAnalysis',
        'doshas',
        'dosha',
        'dosh',
        'analysis',
      ],
    );
    final dynamic bhakootDoshaValue = _resolveKundliValue(
      kundliData,
      const <String>['bhakootDosha', 'bhakoot_dosha', 'bhakutDosha'],
      nestedContainers: const <String>[
        'doshaAnalysis',
        'doshas',
        'dosha',
        'dosh',
        'analysis',
      ],
    );
    final dynamic shaniDoshaValue = _resolveKundliValue(
      kundliData,
      const <String>[
        'shaniDosha',
        'shani_dosha',
        'sadeSati',
        'sadeSatiDosha',
        'dhaiya',
      ],
      nestedContainers: const <String>[
        'doshaAnalysis',
        'doshas',
        'dosha',
        'dosh',
        'analysis',
      ],
    );
    final dynamic guruChandalDoshaValue = _resolveKundliValue(
      kundliData,
      const <String>[
        'guruChandalDosha',
        'guru_chandal_dosha',
        'guruChandalaDosha',
        'guruChandal',
      ],
      nestedContainers: const <String>[
        'doshaAnalysis',
        'doshas',
        'dosha',
        'dosh',
        'analysis',
      ],
    );
    final List<Map<String, dynamic>> dashaTable = _asMapList(
      dashaMap['dashaTable'],
    );

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: <Widget>[
          _buildSection(
            isDark: isDark,
            title: _tr('Kundli Summary', 'कुंडली सारांश'),
            children: <Widget>[
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Name', 'नाम'),
                value: _formatValue(
                  kundliData['name'] ?? kundliData['fullName'],
                ),
                icon: Icons.person_outline_rounded,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Date of Birth', 'जन्म तिथि'),
                value: _formatValue(kundliData['dateOfBirth']),
                icon: Icons.calendar_today_rounded,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Time of Birth', 'जन्म समय'),
                value: _formatValue(
                  kundliData['timeOfBirth'] ?? kundliData['birthTime'],
                ),
                icon: Icons.schedule_rounded,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Latitude', 'अक्षांश'),
                value: _formatValue(kundliData['latitude']),
                icon: Icons.place_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Longitude', 'देशांतर'),
                value: _formatValue(kundliData['longitude']),
                icon: Icons.explore_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Moon Sign', 'चंद्र राशि'),
                value: _formatValue(
                  kundliData['moonSign'] ?? kundliData['rasi'],
                ),
                icon: Icons.nightlight_round,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Lagna', 'लग्न'),
                value: _formatValue(kundliData['lagna']),
                icon: Icons.auto_awesome_rounded,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Nakshatra', 'नक्षत्र'),
                value: _formatValue(
                  kundliData['nakshatra'] ?? panchangMap['nakshatra'],
                ),
                icon: Icons.star_border_rounded,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Pada', 'पाद'),
                value: _formatValue(kundliData['pada'] ?? panchangMap['pada']),
                icon: Icons.looks_one_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Overall Message', 'समग्र संदेश'),
                value: _formatStructuredValue(kundliData['overallMessage']),
                icon: Icons.message_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Health Score', 'हेल्थ स्कोर'),
                value: _formatValue(kundliData['healthScore']),
                icon: Icons.monitor_heart_outlined,
              ),
            ],
          ),
          if (locationMeta.isNotEmpty)
            _buildSection(
              isDark: isDark,
              title: _tr('Location Meta', 'लोकेशन मेटा'),
              children: <Widget>[
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Place', 'स्थान'),
                  value: _formatValue(locationMeta['place']),
                  icon: Icons.location_city_outlined,
                ),
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Timezone', 'टाइमज़ोन'),
                  value: _formatValue(locationMeta['timezone']),
                  icon: Icons.public_rounded,
                ),
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Ayanamsa', 'अयनांश'),
                  value: _formatValue(locationMeta['ayanamsa']),
                  icon: Icons.brightness_2_outlined,
                ),
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Julian Day', 'जूलियन डे'),
                  value: _formatValue(locationMeta['julianDay']),
                  icon: Icons.today_outlined,
                ),
              ],
            ),
          if (chartEntries.isNotEmpty)
            _buildSection(
              isDark: isDark,
              title: _tr('Charts & Positions', 'चार्ट और स्थिति'),
              children: chartEntries
                  .map(
                    (entry) => entry.hasHtml
                        ? _buildHtmlChartTile(isDark: isDark, entry: entry)
                        : _buildInfoTile(
                            isDark: isDark,
                            label: entry.label,
                            value: entry.previewText,
                            icon: entry.icon,
                          ),
                  )
                  .toList(),
            ),
          _buildSection(
            isDark: isDark,
            title: _tr('Dosha Analysis', 'दोष विश्लेषण'),
            children: <Widget>[
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Mangal Dosha', 'मांगलिक दोष'),
                value: _formatDoshaValue(mangalDoshaValue),
                icon: Icons.bolt_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Kaal Sarp Dosha', 'काल सर्प दोष'),
                value: _formatDoshaValue(kaalSarpDoshaValue),
                icon: Icons.waves_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Pitru Dosha', 'पितृ दोष'),
                value: _formatDoshaValue(pitruDoshaValue),
                icon: Icons.family_restroom_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Nadi Dosha', 'नाड़ी दोष'),
                value: _formatDoshaValue(nadiDoshaValue),
                icon: Icons.bloodtype_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Bhakoot Dosha', 'भकूट दोष'),
                value: _formatDoshaValue(bhakootDoshaValue),
                icon: Icons.compare_arrows_rounded,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Grahan Dosha', 'ग्रहण दोष'),
                value: _formatDoshaValue(grahanDoshaValue),
                icon: Icons.dark_mode_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr(
                  'Shani Dosha / Sade Sati / Dhaiya',
                  'शनि दोष / साढ़ेसाती / ढैया',
                ),
                value: _formatDoshaValue(shaniDoshaValue),
                icon: Icons.nights_stay_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Guru Chandal Dosha', 'गुरु चांडाल दोष'),
                value: _formatDoshaValue(guruChandalDoshaValue),
                icon: Icons.school_outlined,
              ),
            ],
          ),
          if (auspiciousYogas.isNotEmpty || inauspiciousYogas.isNotEmpty)
            _buildSection(
              isDark: isDark,
              title: _tr('Yogas', 'योग'),
              children: <Widget>[
                if (auspiciousYogas.isNotEmpty)
                  _buildInfoTile(
                    isDark: isDark,
                    label: _tr('Auspicious Yogas', 'शुभ योग'),
                    value: auspiciousYogas.map((item) => '• $item').join('\n'),
                    icon: Icons.auto_awesome_outlined,
                  ),
                if (inauspiciousYogas.isNotEmpty)
                  _buildInfoTile(
                    isDark: isDark,
                    label: _tr('Inauspicious Yogas', 'अशुभ योग'),
                    value: inauspiciousYogas
                        .map((item) => '• $item')
                        .join('\n'),
                    icon: Icons.warning_amber_outlined,
                  ),
              ],
            ),
          if (dashaMap.isNotEmpty)
            _buildSection(
              isDark: isDark,
              title: _tr('Vimshottari Dasha', 'विम्शोत्तरी दशा'),
              children: <Widget>[
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Current Mahadasha', 'वर्तमान महादशा'),
                  value: _formatValue(dashaMap['currentMahadasha']),
                  icon: Icons.rotate_right_outlined,
                ),
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Current Antardasha', 'वर्तमान अंतरदशा'),
                  value: _formatValue(dashaMap['currentAntardasha']),
                  icon: Icons.repeat_on_outlined,
                ),
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Current Pratyantar', 'वर्तमान प्रत्यंतर'),
                  value: _formatValue(dashaMap['currentPratyantar']),
                  icon: Icons.change_history_outlined,
                ),
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Progress', 'प्रगति'),
                  value: _formatValue(dashaMap['progressionPercentage']),
                  icon: Icons.stacked_line_chart_rounded,
                ),
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Signification', 'महत्व'),
                  value: _formatStructuredValue(
                    dashaMap['mahadashaSignification'],
                  ),
                  icon: Icons.tips_and_updates_outlined,
                ),
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Upcoming Changes', 'आगामी परिवर्तन'),
                  value: _formatStructuredValue(dashaMap['upcomingChanges']),
                  icon: Icons.trending_up_rounded,
                ),
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Remedy Advice', 'उपाय सलाह'),
                  value: _formatStructuredValue(dashaMap['remedyAdvice']),
                  icon: Icons.healing_outlined,
                ),
                if (dashaTable.isNotEmpty)
                  _buildInfoTile(
                    isDark: isDark,
                    label: _tr('Detailed Dasha Table', 'विस्तृत दशा तालिका'),
                    value: dashaTable
                        .map((row) {
                          final period = _formatValue(row['period']);
                          final day = _formatValue(row['day']);
                          final endDate = _formatValue(row['endDate']);
                          return '• $period  $day  $endDate';
                        })
                        .join('\n'),
                    icon: Icons.table_rows_outlined,
                  ),
              ],
            ),
          if (planets.isNotEmpty)
            _buildSection(
              isDark: isDark,
              title: _tr('Planetary Positions', 'ग्रह स्थिति'),
              children: planets.map((planet) {
                final retro = planet['retrograde'] == true
                    ? _tr('Retrograde', 'वक्री')
                    : _tr('Direct', 'मार्गी');
                final value =
                    '${_tr('Rashi', 'राशि')}: ${_formatValue(planet['rashi'])}\n'
                    '${_tr('Degree', 'डिग्री')}: ${_formatValue(planet['degree'])}\n'
                    '${_tr('Longitude', 'देशांतर')}: ${_formatValue(planet['longitude'])}\n'
                    '${_tr('Speed', 'गति')}: ${_formatValue(planet['speed'])}\n'
                    '${_tr('Motion', 'गति प्रकार')}: $retro';
                return _buildInfoTile(
                  isDark: isDark,
                  label: _formatValue(planet['planet']),
                  value: value,
                  icon: Icons.public_outlined,
                );
              }).toList(),
            ),
          if (housesMap.isNotEmpty)
            _buildSection(
              isDark: isDark,
              title: _tr('Houses', 'भाव'),
              children: <Widget>[
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('House Mapping', 'भाव मैपिंग'),
                  value: housesMap.entries
                      .map(
                        (entry) =>
                            '• ${_tr('House', 'भाव')} ${entry.key}: ${_formatValue(entry.value)}',
                      )
                      .join('\n'),
                  icon: Icons.grid_view_rounded,
                ),
              ],
            ),
          if (predominantElementsData != null)
            _buildSection(
              isDark: isDark,
              title: _tr('Predominant Elements', 'प्रधान तत्व'),
              children: <Widget>[
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Element Balance', 'तत्व संतुलन'),
                  value: predominantElementsData.elements.entries
                      .map(
                        (entry) =>
                            '• ${_elementLabel(entry.key)}: ${entry.value.toStringAsFixed(2)}',
                      )
                      .join('\n'),
                  icon: Icons.pie_chart_outline_rounded,
                ),
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Average', 'औसत'),
                  value: predominantElementsData.average.toStringAsFixed(2),
                  icon: Icons.show_chart_rounded,
                ),
              ],
            ),
          if (remediesMap.isNotEmpty)
            _buildSection(
              isDark: isDark,
              title: _tr('Remedies', 'उपाय'),
              children: remediesMap.entries.map((entry) {
                return _buildInfoTile(
                  isDark: isDark,
                  label: _humanizeKey(entry.key),
                  value: _toBulletLines(entry.value),
                  icon: Icons.volunteer_activism_outlined,
                );
              }).toList(),
            ),
          if (panchangMap.isNotEmpty)
            _buildSection(
              isDark: isDark,
              title: _tr('Kundli Panchang', 'कुंडली पंचांग'),
              children: <Widget>[
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Tithi', 'तिथि'),
                  value: _formatStructuredValue(
                    panchangMap['tithi'] ?? panchangMap['tithiDetails'],
                  ),
                  icon: Icons.brightness_6_outlined,
                ),
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Nakshatra', 'नक्षत्र'),
                  value: _formatStructuredValue(
                    panchangMap['nakshatra'] ?? panchangMap['nakshatraDetails'],
                  ),
                  icon: Icons.star_border_rounded,
                ),
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Yoga', 'योग'),
                  value: _formatStructuredValue(panchangMap['yoga']),
                  icon: Icons.spa_outlined,
                ),
                _buildInfoTile(
                  isDark: isDark,
                  label: _tr('Karana', 'करण'),
                  value: _formatStructuredValue(panchangMap['karana']),
                  icon: Icons.timeline_rounded,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPanchangTab(bool isDark) {
    final panchangData = _payload(_panchang);
    if (panchangData.isEmpty) {
      return _UserInsightState(
        icon: Icons.calendar_month_outlined,
        title: _tr('Panchang unavailable', 'पंचांग उपलब्ध नहीं है'),
        subtitle: _tr(
          'Unable to load panchang for this user.',
          'इस यूज़र के लिए पंचांग लोड नहीं हो पाया।',
        ),
      );
    }

    final tithiMap =
        _asMap(panchangData['tithi'] ?? panchangData['tithiDetails']) ??
        <String, dynamic>{};
    final nakshatraMap =
        _asMap(panchangData['nakshatra'] ?? panchangData['nakshatraDetails']) ??
        <String, dynamic>{};
    final yogaMap = _asMap(panchangData['yoga']) ?? <String, dynamic>{};
    final karanaMap = _asMap(panchangData['karana']) ?? <String, dynamic>{};
    final phaseMap = _asMap(panchangData['phase']) ?? <String, dynamic>{};
    final progressMap = _asMap(panchangData['progress']) ?? <String, dynamic>{};
    final sunPosMap =
        _asMap(panchangData['sunPosition']) ?? <String, dynamic>{};
    final moonPosMap =
        _asMap(panchangData['moonPosition']) ?? <String, dynamic>{};
    final metaMap = _asMap(panchangData['meta']) ?? <String, dynamic>{};
    final rahuKaal = _resolveRahuKaal(panchangData);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: <Widget>[
          _buildSection(
            isDark: isDark,
            title: _tr('Today Panchang', 'आज का पंचांग'),
            children: <Widget>[
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Date', 'तारीख'),
                value: _formatValue(
                  panchangData['date'] ??
                      panchangData['dateTime'] ??
                      panchangData['currentDate'],
                ),
                icon: Icons.calendar_month_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Day', 'वार'),
                value: _formatValue(
                  panchangData['dayOfWeek'] ?? panchangData['vara'],
                ),
                icon: Icons.today_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Weekday Lord', 'वार स्वामी'),
                value: _formatValue(panchangData['weekdayLord']),
                icon: Icons.star_outline_rounded,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Tithi', 'तिथि'),
                value: _formatStructuredValue(
                  tithiMap.isEmpty ? panchangData['tithi'] : tithiMap,
                ),
                icon: Icons.brightness_6_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Nakshatra', 'नक्षत्र'),
                value: _formatStructuredValue(
                  nakshatraMap.isEmpty
                      ? panchangData['nakshatra']
                      : nakshatraMap,
                ),
                icon: Icons.star_border_rounded,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Yoga', 'योग'),
                value: _formatStructuredValue(
                  yogaMap.isEmpty ? panchangData['yoga'] : yogaMap,
                ),
                icon: Icons.spa_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Karana', 'करण'),
                value: _formatStructuredValue(
                  karanaMap.isEmpty ? panchangData['karana'] : karanaMap,
                ),
                icon: Icons.timeline_rounded,
              ),
            ],
          ),
          _buildSection(
            isDark: isDark,
            title: _tr('Timings', 'समय विवरण'),
            children: <Widget>[
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Sunrise', 'सूर्योदय'),
                value: _formatValue(
                  panchangData['sunrise'] ?? panchangData['sunRise'],
                ),
                icon: Icons.wb_twilight_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Sunset', 'सूर्यास्त'),
                value: _formatValue(
                  panchangData['sunset'] ?? panchangData['sunSet'],
                ),
                icon: Icons.nightlight_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Moonrise', 'चंद्रोदय'),
                value: _formatValue(panchangData['moonrise']),
                icon: Icons.brightness_3_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Moonset', 'चंद्रास्त'),
                value: _formatValue(panchangData['moonset']),
                icon: Icons.bedtime_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Rahu Kaal', 'राहु काल'),
                value: rahuKaal,
                icon: Icons.hourglass_bottom_rounded,
              ),
            ],
          ),
          _buildSection(
            isDark: isDark,
            title: _tr('Astronomical Details', 'खगोलीय विवरण'),
            children: <Widget>[
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Rashi', 'राशि'),
                value: _formatValue(panchangData['rashi']),
                icon: Icons.auto_awesome_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Sun Longitude', 'सूर्य देशांतर'),
                value: _formatValue(panchangData['sunLongitude']),
                icon: Icons.wb_sunny_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Moon Longitude', 'चंद्र देशांतर'),
                value: _formatValue(panchangData['moonLongitude']),
                icon: Icons.nightlight_round,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Julian Day', 'जूलियन डे'),
                value: _formatValue(panchangData['julianDay']),
                icon: Icons.today_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Latitude', 'अक्षांश'),
                value: _formatValue(panchangData['latitude']),
                icon: Icons.place_outlined,
              ),
              _buildInfoTile(
                isDark: isDark,
                label: _tr('Longitude', 'देशांतर'),
                value: _formatValue(panchangData['longitude']),
                icon: Icons.explore_outlined,
              ),
            ],
          ),
          if (phaseMap.isNotEmpty || progressMap.isNotEmpty)
            _buildSection(
              isDark: isDark,
              title: _tr('Lunar Phase & Progress', 'चंद्र चरण व प्रगति'),
              children: <Widget>[
                if (phaseMap.isNotEmpty)
                  _buildInfoTile(
                    isDark: isDark,
                    label: _tr('Phase', 'चरण'),
                    value: _formatStructuredValue(phaseMap),
                    icon: Icons.brightness_4_outlined,
                  ),
                if (progressMap.isNotEmpty)
                  _buildInfoTile(
                    isDark: isDark,
                    label: _tr('Progress', 'प्रगति'),
                    value: _formatStructuredValue(progressMap),
                    icon: Icons.trending_up_rounded,
                  ),
              ],
            ),
          if (sunPosMap.isNotEmpty || moonPosMap.isNotEmpty)
            _buildSection(
              isDark: isDark,
              title: _tr('Sun & Moon Position', 'सूर्य व चंद्र स्थिति'),
              children: <Widget>[
                if (sunPosMap.isNotEmpty)
                  _buildInfoTile(
                    isDark: isDark,
                    label: _tr('Sun Position', 'सूर्य स्थिति'),
                    value: _formatStructuredValue(sunPosMap),
                    icon: Icons.wb_sunny_outlined,
                  ),
                if (moonPosMap.isNotEmpty)
                  _buildInfoTile(
                    isDark: isDark,
                    label: _tr('Moon Position', 'चंद्र स्थिति'),
                    value: _formatStructuredValue(moonPosMap),
                    icon: Icons.brightness_3_outlined,
                  ),
              ],
            ),
          if (metaMap.isNotEmpty)
            _buildSection(
              isDark: isDark,
              title: _tr('Panchang Meta', 'पंचांग मेटा'),
              children: metaMap.entries.map((entry) {
                return _buildInfoTile(
                  isDark: isDark,
                  label: _humanizeKey(entry.key),
                  value: _formatStructuredValue(entry.value),
                  icon: Icons.info_outline_rounded,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _UserInsightState extends StatelessWidget {
  const _UserInsightState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 42,
              color: isDark ? AdminAppTheme.gold : AdminAppTheme.royal,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AdminAppTheme.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : AdminAppTheme.muted,
                fontSize: 13,
              ),
            ),
            if (onAction != null && (actionLabel ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
