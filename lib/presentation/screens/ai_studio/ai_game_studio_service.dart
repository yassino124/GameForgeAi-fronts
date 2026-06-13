import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/services/api_service.dart';


class AiGameStudioService {
  static String get _baseUrl => ApiService.baseUrl;

  /// Kick off a full scratch Unity game generation.
  static Future<Map<String, dynamic>> generateFromScratch({
    required String token,
    required String prompt,
    String buildTarget = 'webgl',
    bool withAiSprites = false,
    String? userSpriteBase64,
  }) async {
    final body = <String, dynamic>{
      'prompt': prompt,
      'buildTarget': buildTarget,
      'withAiSprites': withAiSprites,
      if (userSpriteBase64 != null) 'userSpriteBase64': userSpriteBase64,
    };

    final res = await http.post(
      Uri.parse('$_baseUrl/ai/generate-from-scratch'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(data['message'] ?? 'Generation failed');
    }
    return data;
  }

  /// Preview the GDD without starting a build.
  static Future<Map<String, dynamic>> previewGdd({
    required String token,
    required String prompt,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/ai/generate-gdd-preview'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'prompt': prompt}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(data['message'] ?? 'GDD preview failed');
    }
    return data;
  }

  /// Poll granular phase status for the 5-step progress tracker.
  static Future<Map<String, dynamic>> pollStatus({
    required String token,
    required String projectId,
  }) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/ai/scratch-status/$projectId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(data['message'] ?? 'Status poll failed');
    }
    return data;
  }
}
