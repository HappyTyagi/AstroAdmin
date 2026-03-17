import '../models/puja_call_models.dart';
import 'api_client.dart';

class PujaCallService {
  final ApiClient _client = ApiClient();

  Future<PujaAgoraLink> generateAgoraLink({
    required int bookingId,
    String callType = 'video',
  }) async {
    final response = await _client.post(
      '/puja/$bookingId/generate-agora-link',
      data: <String, dynamic>{'callType': callType},
    );

    final data = response.data;
    if (data is! Map) {
      throw Exception('Invalid response from server');
    }
    final payload = Map<String, dynamic>.from(data);
    final link = PujaAgoraLink.fromJson(payload);
    if (!link.success) {
      throw Exception(link.message.isEmpty ? 'Unable to generate call link' : link.message);
    }
    return link;
  }
}

