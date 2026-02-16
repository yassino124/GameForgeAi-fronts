import 'api_service.dart';

class NotificationsService {
  static Future<Map<String, dynamic>> listNotifications({required String token}) async {
    return ApiService.get('/notifications', token: token);
  }

  static Future<Map<String, dynamic>> markNotificationRead({
    required String token,
    required String notificationId,
    required bool isRead,
  }) async {
    return ApiService.patch(
      '/notifications/$notificationId',
      token: token,
      data: {'isRead': isRead},
    );
  }

  static Future<Map<String, dynamic>> markAllRead({required String token}) async {
    return ApiService.post('/notifications/read-all', token: token);
  }

  static Future<Map<String, dynamic>> clearAll({required String token}) async {
    return ApiService.post('/notifications/clear-all', token: token);
  }
}
