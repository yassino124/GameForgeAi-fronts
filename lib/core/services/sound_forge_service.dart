import 'api_service.dart';

class SoundForgeService {
  /* ─── Get user library ─── */
  static Future<Map<String, dynamic>> getLibrary({required String token}) async {
    return ApiService.get('/audio/library', token: token);
  }

  /* ─── Get tracks for a project ─── */
  static Future<Map<String, dynamic>> getProjectTracks({
    required String token,
    required String projectId,
  }) async {
    return ApiService.get('/audio/project/$projectId', token: token);
  }

  /* ─── Generate audio track ─── */
  static Future<Map<String, dynamic>> generateTrack({
    required String token,
    required String type,   // 'music' | 'sfx'
    required String genre,
    required String prompt,
    String? title,
    String? projectId,
    int duration = 30,
  }) async {
    return ApiService.post(
      '/audio/generate',
      token: token,
      data: {
        'type': type,
        'genre': genre,
        'prompt': prompt,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        // projectId optional — use placeholder if not in a project context
        'projectId': (projectId != null && projectId.trim().isNotEmpty)
            ? projectId.trim()
            : 'library',
        'duration': duration,
      },
    );
  }

  /* ─── Toggle favorite ─── */
  static Future<Map<String, dynamic>> toggleFavorite({
    required String token,
    required String trackId,
  }) async {
    return ApiService.patch('/audio/$trackId/favorite', token: token);
  }

  /* ─── Delete track ─── */
  static Future<Map<String, dynamic>> deleteTrack({
    required String token,
    required String trackId,
  }) async {
    return ApiService.delete('/audio/$trackId', token: token);
  }

  /* ─── Ollama health check ─── */
  static Future<bool> checkOllamaHealth() async {
    try {
      final res = await ApiService.get('/audio/ollama/health');
      return res['data']?['online'] == true || res['online'] == true;
    } catch (_) {
      return false;
    }
  }
}
