import 'api_service.dart';

class UsersService {
  static Future<Map<String, dynamic>> getMyStats({
    required String token,
  }) async {
    return ApiService.get('/users/me/stats', token: token);
  }

  static Future<Map<String, dynamic>> getPublicProfile({
    required String token,
    required String userId,
  }) async {
    return ApiService.get('/users/${userId.trim()}/public', token: token);
  }
}
