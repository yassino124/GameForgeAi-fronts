import 'api_service.dart';

class GameGenService {
  static Future<Map<String, dynamic>> generateStream({
    required String token,
    required String prompt,
  }) async {
    return ApiService.post(
      '/ai/game-gen/generate-stream',
      token: token,
      data: {
        'prompt': prompt.trim(),
      },
      timeout: const Duration(seconds: 180),
    );
  }
}
