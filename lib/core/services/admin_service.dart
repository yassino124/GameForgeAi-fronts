import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_service.dart';

/// Admin dashboard API - uses ApiService for HTTP calls.
class AdminService {
  AdminService._();

  static Future<Map<String, dynamic>> getDashboard({required String token}) {
    return ApiService.get('/admin/dashboard', token: token);
  }

  static Future<Map<String, dynamic>> getTemplates({required String token}) {
    return ApiService.get('/admin/templates', token: token);
  }

  static Future<Map<String, dynamic>> getAdminProjects({required String token}) {
    return ApiService.get('/admin/projects', token: token);
  }

  static Future<Map<String, dynamic>> getAdminBuilds({required String token}) {
    return ApiService.get('/admin/builds', token: token);
  }

  static Future<Map<String, dynamic>> getAdminActivity({required String token}) {
    return ApiService.get('/admin/recent-activity', token: token);
  }

  static Future<Map<String, dynamic>> getSystemStatus({required String token}) {
    return ApiService.get('/admin/system-status', token: token);
  }

  static Future<Map<String, dynamic>> getNotificationsHistory({required String token}) {
    return ApiService.get('/admin/notifications-history', token: token);
  }

  static Future<Map<String, dynamic>> generateAiInsights({required String token}) {
    return ApiService.post('/admin/ai-insights', data: {}, token: token);
  }

  /// Upload a new template to the backend
  /// POST /templates/upload with multipart/form-data
  /// Uses Uint8List for web compatibility (no file paths on web)
  static Future<Map<String, dynamic>> uploadTemplate({
    required String token,
    required Uint8List zipFileBytes,
    required String zipFileName,
    String? name,
    String? description,
    String? category,
    String? tags,
    String? price,
    Uint8List? previewImageBytes,
    String? previewImageFileName,
    List<Uint8List>? screenshotsBytes,
    List<String>? screenshotFileNames,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/templates/upload'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Add text fields
      final fields = <String, String>{};
      if (name != null) fields['name'] = name;
      if (description != null) fields['description'] = description;
      if (category != null) fields['category'] = category;
      if (tags != null) fields['tags'] = tags;
      if (price != null) fields['price'] = price;
      request.fields.addAll(fields);

      // Add zip file (required)
      request.files.add(
        http.MultipartFile.fromBytes('file', zipFileBytes, filename: zipFileName),
      );

      // Add preview image if provided
      if (previewImageBytes != null && previewImageFileName != null) {
        request.files.add(
          http.MultipartFile.fromBytes('previewImage', previewImageBytes, filename: previewImageFileName),
        );
      }

      // Add screenshots if provided
      if (screenshotsBytes != null && screenshotFileNames != null) {
        for (int i = 0; i < screenshotsBytes.length && i < screenshotFileNames.length; i++) {
          request.files.add(
            http.MultipartFile.fromBytes('screenshots', screenshotsBytes[i], filename: screenshotFileNames[i]),
          );
        }
      }

      final response = await request.send().timeout(const Duration(seconds: 60));
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
      return jsonResponse;
    } on TimeoutException {
      return {'success': false, 'message': 'Upload timed out. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': 'Upload failed: $e'};
    }
  }

  /// Update an existing template metadata
  /// PATCH /templates/:id with JSON body
  /// Optional zipFileBytes for re-uploading the template file
  static Future<Map<String, dynamic>> updateTemplate({
    required String token,
    required String templateId,
    Uint8List? zipFileBytes,
    String? zipFileName,
    String? name,
    String? description,
    String? category,
    String? tags,
    String? price,
    Uint8List? previewImageBytes,
    String? previewImageFileName,
    List<Uint8List>? screenshotsBytes,
    List<String>? screenshotFileNames,
  }) async {
    try {
      // If zip file is provided, use multipart request (like upload)
      if (zipFileBytes != null) {
        final request = http.MultipartRequest(
          'PATCH',
          Uri.parse('${ApiService.baseUrl}/templates/$templateId'),
        );

        request.headers['Authorization'] = 'Bearer $token';
        request.headers['Accept'] = 'application/json';

        // Add text fields
        final fields = <String, String>{};
        if (name != null) fields['name'] = name;
        if (description != null) fields['description'] = description;
        if (category != null) fields['category'] = category;
        if (tags != null) fields['tags'] = tags;
        if (price != null) fields['price'] = price;
        request.fields.addAll(fields);

        // Add zip file
        request.files.add(
          http.MultipartFile.fromBytes('file', zipFileBytes, filename: zipFileName ?? 'template.zip'),
        );

        // Add preview image if provided
        if (previewImageBytes != null && previewImageFileName != null) {
          request.files.add(
            http.MultipartFile.fromBytes('previewImage', previewImageBytes, filename: previewImageFileName),
          );
        }

        // Add screenshots if provided
        if (screenshotsBytes != null && screenshotFileNames != null) {
          for (int i = 0; i < screenshotsBytes.length && i < screenshotFileNames.length; i++) {
            request.files.add(
              http.MultipartFile.fromBytes('screenshots', screenshotsBytes[i], filename: screenshotFileNames[i]),
            );
          }
        }

        final response = await request.send();
        final responseBody = await response.stream.bytesToString();
        final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
        return jsonResponse;
      } else {
        // No zip file: use simple PATCH with JSON body for metadata only
        final data = <String, dynamic>{};
        if (name != null) data['name'] = name;
        if (description != null) data['description'] = description;
        if (category != null) data['category'] = category;
        if (tags != null) data['tags'] = tags;
        if (price != null) data['price'] = price;

        return ApiService.patch('/templates/$templateId', data: data, token: token);
      }
    } catch (e) {
      return {'success': false, 'message': 'Update failed: $e'};
    }
  }

  /// Generate AI description for a template
  static Future<Map<String, dynamic>> generateAiDescription({
    required String token,
    required String name,
    required String category,
    String? tags,
  }) async {
    return ApiService.post(
      '/admin/ai-description',
      data: {
        'name': name,
        'category': category,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
      },
      token: token,
    );
  }

  /// Analyze a build error with AI
  static Future<Map<String, dynamic>> analyzeAiBuildError({
    required String token,
    required String errorMessage,
    String? buildTarget,
    String? projectName,
  }) async {
    return ApiService.post(
      '/admin/ai-analyze-error',
      data: {
        'errorMessage': errorMessage,
        if (buildTarget != null && buildTarget.isNotEmpty) 'buildTarget': buildTarget,
        if (projectName != null && projectName.isNotEmpty) 'projectName': projectName,
      },
      token: token,
    );
  }

  /// Send real-time notification to users
  static Future<Map<String, dynamic>> sendRealtimeNotification({
    required String token,
    required String title,
    required String message,
    required String target,
  }) {
    final bool sendToAll = target == 'All Users';

    return ApiService.post(
      '/admin/send-notification',
      data: {
        'title': title,
        'message': message,
        // Backend enum only accepts: info|success|warning|error
        'type': 'info',
        'sendToAll': sendToAll,
      },
      token: token,
    );
  }

  // FIX 1: Hide project from dashboard
  static Future<Map<String, dynamic>> hideProject({
    required String token,
    required String projectId,
  }) {
    return ApiService.patch('/admin/projects/$projectId/hide', data: {}, token: token);
  }

  // FIX 2: Archive project
  static Future<Map<String, dynamic>> archiveProject({
    required String token,
    required String projectId,
  }) {
    return ApiService.patch('/admin/projects/$projectId/archive', data: {}, token: token);
  }

  // Unarchive project
  static Future<Map<String, dynamic>> unarchiveProject({
    required String token,
    required String projectId,
  }) {
    return ApiService.patch('/admin/projects/$projectId/unarchive', data: {}, token: token);
  }

  // FIX 3: Toggle template active status
  static Future<Map<String, dynamic>> toggleTemplate({
    required String token,
    required String templateId,
  }) {
    return ApiService.patch('/admin/templates/$templateId/toggle', data: {}, token: token);
  }

  // FIX 4: Get build logs
  static Future<Map<String, dynamic>> getBuildLogs({
    required String token,
    required String buildId,
  }) {
    return ApiService.get('/admin/builds/$buildId/logs', token: token);
  }

  // FIX 6: Revoke all sessions
  static Future<Map<String, dynamic>> revokeAllSessions({required String token}) {
    return ApiService.post('/admin/sessions/revoke-all', data: {}, token: token);
  }

  // FIX 7: Get health metrics
  static Future<Map<String, dynamic>> getHealthMetrics({required String token}) {
    return ApiService.get('/admin/health', token: token);
  }

  // FIX 8: AI search
  static Future<Map<String, dynamic>> aiSearch({
    required String token,
    required String query,
  }) {
    return ApiService.post('/admin/ai-search', data: {'query': query}, token: token);
  }
}
