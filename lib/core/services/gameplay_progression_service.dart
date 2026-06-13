import 'api_service.dart';

class GameplayProgressionService {
  static Future<Map<String, dynamic>> me({required String token}) {
    return ApiService.get('/gameplay/progression/me', token: token);
  }

  static Future<Map<String, dynamic>> cards({required String token}) {
    return ApiService.get('/gameplay/cards', token: token);
  }

  static Future<Map<String, dynamic>> rewards({required String token}) {
    return ApiService.get('/gameplay/rewards/me', token: token);
  }

  static Future<Map<String, dynamic>> syncRewards({required String token}) {
    return ApiService.post('/gameplay/progression/sync-rewards', token: token);
  }

  static Future<Map<String, dynamic>> finalizeRun({
    required String token,
    required int score,
    int durationSec = 60,
    String? projectId,
    Map<String, dynamic>? gameplayData,
  }) {
    return ApiService.post(
      '/gameplay/finalize-run',
      token: token,
      data: {
        'score': score,
        'durationSec': durationSec,
        if (projectId != null && projectId.trim().isNotEmpty)
          'projectId': projectId.trim(),
        if (gameplayData != null) 'gameplayData': gameplayData,
      },
    );
  }

  static Future<Map<String, dynamic>> mintCard({
    required String token,
    required String cardId,
  }) {
    return ApiService.post('/gameplay/cards/${cardId.trim()}/mint', token: token);
  }

  static Future<Map<String, dynamic>> setWalletAddress({
    required String token,
    required String address,
  }) {
    return ApiService.post(
      '/gameplay/progression/wallet',
      token: token,
      data: {'address': address.trim()},
    );
  }
}
