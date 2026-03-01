import 'api_service.dart';
import 'admin_users_service_stub.dart'
    if (dart.library.html) 'admin_users_service_web.dart' as web_impl;

/// Admin users API - uses ApiService for HTTP calls.
class AdminUsersService {
  AdminUsersService._();

  static String _buildQuery(Map<String, String?> params) {
    final parts = <String>[];
    params.forEach((k, v) {
      if (v != null && v.toString().trim().isNotEmpty) {
        parts.add('$k=${Uri.encodeComponent(v.trim())}');
      }
    });
    return parts.isEmpty ? '' : '?${parts.join('&')}';
  }

  static Future<Map<String, dynamic>> getUsers({
    required String token,
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
    String? role,
    String? subscription,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, String?>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null && status != 'all') 'status': status,
      if (role != null && role != 'all') 'role': role,
      if (subscription != null && subscription != 'all') 'subscription': subscription,
      if (dateFrom != null && dateFrom.trim().isNotEmpty) 'dateFrom': dateFrom.trim(),
      if (dateTo != null && dateTo.trim().isNotEmpty) 'dateTo': dateTo.trim(),
    };
    final q = _buildQuery(params);
    return ApiService.get('/admin/users$q', token: token);
  }

  static Future<Map<String, dynamic>> getUser(String id, String token) {
    return ApiService.get('/admin/users/$id', token: token);
  }

  static Future<Map<String, dynamic>> getUserProjects(String userId, String token) {
    return ApiService.get('/admin/users/$userId/projects', token: token);
  }

  static Future<Map<String, dynamic>> getUserActivity(String userId, String token) {
    return ApiService.get('/admin/users/$userId/activity', token: token);
  }

  static Future<Map<String, dynamic>> updateUserStatus({
    required String id,
    required String status,
    required String token,
  }) {
    return ApiService.patch('/admin/users/$id/status', data: {'status': status}, token: token);
  }

  static Future<Map<String, dynamic>> deleteUser(String id, String token) {
    return ApiService.delete('/admin/users/$id', token: token);
  }

  static Future<Map<String, dynamic>> exportCsv({
    required String token,
    String? search,
    String? status,
    String? role,
    String? subscription,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, String?>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null && status != 'all') 'status': status,
      if (role != null && role != 'all') 'role': role,
      if (subscription != null && subscription != 'all') 'subscription': subscription,
      if (dateFrom != null && dateFrom.trim().isNotEmpty) 'dateFrom': dateFrom.trim(),
      if (dateTo != null && dateTo.trim().isNotEmpty) 'dateTo': dateTo.trim(),
    };
    final q = _buildQuery(params);
    return ApiService.getRaw('/admin/users/export/csv$q', token: token);
  }

  /// Trigger CSV download in browser (web only).
  static Future<bool> downloadCsv({
    required String token,
    String? search,
    String? status,
    String? role,
    String? subscription,
    String? dateFrom,
    String? dateTo,
  }) async {
    final res = await exportCsv(
      token: token,
      search: search,
      status: status,
      role: role,
      subscription: subscription,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    if (res['success'] != true || res['data'] == null) return false;
    final csv = res['data'] is String ? res['data'] as String : res['data'].toString();
    web_impl.downloadCsvWeb(csv);
    return true;
  }
}
