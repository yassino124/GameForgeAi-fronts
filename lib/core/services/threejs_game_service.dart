import 'api_service.dart';

class ThreeJsGameService {
  static Future<Map<String, dynamic>> generate({
    required String token,
    required String prompt,
    String? gameType,
    Duration timeout = const Duration(seconds: 180),
  }) async {
    return ApiService.post(
      '/ai/threejs/generate',
      token: token,
      timeout: timeout,
      data: {
        'prompt': prompt.trim(),
        if (gameType != null) 'gameType': gameType,
      },
    );
  }

  static Future<Map<String, dynamic>> status({
    required String token,
    required String gameId,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return ApiService.get(
      '/ai/threejs/status/$gameId',
      token: token,
      timeout: timeout,
    );
  }
}
