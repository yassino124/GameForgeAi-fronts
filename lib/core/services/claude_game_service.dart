import 'api_service.dart';

class ClaudeGameService {
  /// POST /ai/claude/generate-game
  /// Enqueues a Claude game generation job and returns { gameId, status }.
  static Future<Map<String, dynamic>> generate({
    required String token,
    required String prompt,
    String style = 'auto',
    Duration timeout = const Duration(seconds: 180),
  }) async {
    return ApiService.post(
      '/ai/claude/generate-game',
      token: token,
      timeout: timeout,
      data: {
        'prompt': prompt.trim(),
        'style': style.trim().isEmpty ? 'auto' : style.trim(),
      },
    );
  }

  /// GET /ai/claude/status/:gameId
  /// Polls generation status. Returns { gameId, status, playUrl, error, title, description }.
  static Future<Map<String, dynamic>> status({
    required String token,
    required String gameId,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return ApiService.get(
      '/ai/claude/status/$gameId',
      token: token,
      timeout: timeout,
    );
  }
}
