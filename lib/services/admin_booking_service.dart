import '../models/admin_booking_models.dart';
import 'api_client.dart';
import 'api_config.dart';

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
}
