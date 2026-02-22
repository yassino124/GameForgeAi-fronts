import 'api_service.dart';

/// Admin dashboard API - uses ApiService for HTTP calls.
class AdminService {
  AdminService._();

  static Future<Map<String, dynamic>> getDashboard({required String token}) {
    return ApiService.get('/admin/dashboard', token: token);
  }

  static Future<Map<String, dynamic>> getTemplates({required String token}) {
    return ApiService.get('/templates', token: token);
  }
}
