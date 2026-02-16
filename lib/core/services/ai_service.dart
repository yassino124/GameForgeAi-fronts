import 'api_service.dart';

class AiService {
  static Future<Map<String, dynamic>> listModels({
    required String token,
  }) async {
    return ApiService.get('/ai/models', token: token);
  }

  static Future<Map<String, dynamic>> listTrends({
    required String token,
  }) async {
    return ApiService.get('/ai/trends', token: token);
  }

  static Future<Map<String, dynamic>> generateTemplateDraft({
    required String token,
    required String description,
    String? notes,
  }) async {
    return ApiService.post(
      '/ai/draft/template',
      token: token,
      data: {
        'description': description.trim(),
        if (notes != null) 'notes': notes.trim(),
      },
    );
  }

  static Future<Map<String, dynamic>> generateProjectDraft({
    required String token,
    required String description,
    String? notes,
  }) async {
    return ApiService.post(
      '/ai/draft/project',
      token: token,
      data: {
        'description': description.trim(),
        if (notes != null) 'notes': notes.trim(),
      },
    );
  }

  static Future<Map<String, dynamic>> generateImage({
    required String token,
    required String prompt,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    return ApiService.post(
      '/ai/image',
      token: token,
      timeout: timeout,
      data: {
        'prompt': prompt.trim(),
      },
    );
  }
}
