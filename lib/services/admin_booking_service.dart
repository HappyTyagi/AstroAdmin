import '../models/admin_booking_models.dart';
import 'api_client.dart';
import 'api_config.dart';

class AdminPagedResult<T> {
  final List<T> items;
  final int page;
  final int size;
  final int total;
  final bool hasNext;

  const AdminPagedResult({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
    required this.hasNext,
  });
}

class AdminBookingService {
  final ApiClient _client = ApiClient();

  Future<List<AdminPujaBooking>> fetchPujaBookings() async {
    final response = await _client.get(ApiConfig.adminPujaBookings);
    final map = Map<String, dynamic>.from(response.data as Map);
    final items = (map['bookings'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (dynamic item) =>
              AdminPujaBooking.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    return items;
  }

  Future<List<AdminRemedyBooking>> fetchRemedyBookings() async {
    final response = await _client.get(ApiConfig.adminRemedyBookings);
    final map = Map<String, dynamic>.from(response.data as Map);
    final items = (map['bookings'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (dynamic item) => AdminRemedyBooking.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    return items;
  }

  Future<AdminPagedResult<AdminPujaBooking>> fetchPujaBookingsPage({
    required int page,
    int size = 12,
    String search = '',
  }) async {
    final int safePage = page < 0 ? 0 : page;
    final int safeSize = size <= 0 ? 12 : size;
    final String trimmedSearch = search.trim();

    final response = await _client.get(
      ApiConfig.adminPujaBookings,
      queryParameters: <String, dynamic>{
        'page': safePage,
        'size': safeSize,
        if (trimmedSearch.isNotEmpty) 'search': trimmedSearch,
      },
    );
    final map = Map<String, dynamic>.from(response.data as Map);
    final items = (map['bookings'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (dynamic item) =>
              AdminPujaBooking.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final int total =
        _readInt(map['count'] ?? map['total'] ?? map['totalCount']) ??
        items.length;
    final bool hasNext =
        _readBool(map['hasNext']) ?? ((safePage + 1) * safeSize < total);
    return AdminPagedResult<AdminPujaBooking>(
      items: items,
      page: _readInt(map['page']) ?? safePage,
      size: _readInt(map['size']) ?? safeSize,
      total: total,
      hasNext: hasNext,
    );
  }

  Future<AdminPagedResult<AdminRemedyBooking>> fetchRemedyBookingsPage({
    required int page,
    int size = 12,
    String search = '',
  }) async {
    final int safePage = page < 0 ? 0 : page;
    final int safeSize = size <= 0 ? 12 : size;
    final String trimmedSearch = search.trim();

    final response = await _client.get(
      ApiConfig.adminRemedyBookings,
      queryParameters: <String, dynamic>{
        'page': safePage,
        'size': safeSize,
        if (trimmedSearch.isNotEmpty) 'search': trimmedSearch,
      },
    );
    final map = Map<String, dynamic>.from(response.data as Map);
    final items = (map['bookings'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (dynamic item) => AdminRemedyBooking.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    final int total =
        _readInt(map['count'] ?? map['total'] ?? map['totalCount']) ??
        items.length;
    final bool hasNext =
        _readBool(map['hasNext']) ?? ((safePage + 1) * safeSize < total);
    return AdminPagedResult<AdminRemedyBooking>(
      items: items,
      page: _readInt(map['page']) ?? safePage,
      size: _readInt(map['size']) ?? safeSize,
      total: total,
      hasNext: hasNext,
    );
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString());
  }

  bool? _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String text = (value ?? '').toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return null;
  }
}
