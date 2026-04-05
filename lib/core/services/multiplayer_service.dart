import 'api_service.dart';

class MultiplayerService {
  static Future<Map<String, dynamic>> listPublicRooms({
    required String token,
    int limit = 20,
    String? cursor,
    String? q,
  }) {
    final qp = <String, String>{
      'limit': limit.toString(),
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    };

    final qs = Uri(queryParameters: qp).query;
    final endpoint = '/multiplayer/rooms${qs.isNotEmpty ? '?$qs' : ''}';

    return ApiService.get(endpoint, token: token);
  }

  static Future<Map<String, dynamic>> getRoom({
    required String token,
    required String roomId,
  }) {
    return ApiService.get('/multiplayer/rooms/${roomId.trim()}', token: token);
  }

  static Future<Map<String, dynamic>> listMessages({
    required String token,
    required String roomId,
    int limit = 50,
    String? before,
  }) {
    final qp = <String, String>{
      'limit': limit.toString(),
      if (before != null && before.trim().isNotEmpty) 'before': before.trim(),
    };

    final qs = Uri(queryParameters: qp).query;
    final endpoint = '/multiplayer/rooms/${roomId.trim()}/messages${qs.isNotEmpty ? '?$qs' : ''}';
    return ApiService.get(endpoint, token: token);
  }
}
