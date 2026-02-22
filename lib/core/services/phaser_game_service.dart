import 'api_service.dart';

class PhaserGameService {
  static Future<Map<String, dynamic>> generate({
    required String token,
    required String prompt,
  }) async {
    return ApiService.post(
      '/ai/phaser/generate',
      token: token,
      data: {
        'prompt': prompt.trim(),
      },
      timeout: const Duration(seconds: 120),
    );
  }

  static Future<Map<String, dynamic>> status({
    required String token,
    required String gameId,
  }) async {
    return ApiService.get(
      '/ai/phaser/status/$gameId',
      token: token,
      timeout: const Duration(seconds: 120),
    );
  }
}
