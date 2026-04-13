import 'api_service.dart';

class DailyRewardsService {
  static Future<Map<String, dynamic>> status({required String token}) {
    return ApiService.get('/daily/status', token: token);
  }

  static Future<Map<String, dynamic>> claim({required String token}) {
    return ApiService.post('/daily/claim', token: token);
  }

  static Future<Map<String, dynamic>> spin({required String token}) {
    return ApiService.post('/daily/spin', token: token);
  }

  static Future<Map<String, dynamic>> openMysteryBox({required String token}) {
    return ApiService.post('/daily/mystery-box/open', token: token);
  }

  static Future<Map<String, dynamic>> wallet({required String token}) {
    return ApiService.get('/daily/wallet', token: token);
  }

  static Future<Map<String, dynamic>> redeem({
    required String token,
    required String walletItemId,
  }) {
    return ApiService.post(
      '/daily/redeem',
      token: token,
      data: {'walletItemId': walletItemId.trim()},
    );
  }

  static Future<Map<String, dynamic>> awardXp({
    required String token,
    required int xp,
    String source = 'quiz',
    Map<String, dynamic>? meta,
  }) {
    return ApiService.post(
      '/daily/award-xp',
      token: token,
      data: {'xp': xp, 'source': source, if (meta != null) 'meta': meta},
    );
  }

  static Future<Map<String, dynamic>> creatorMissions({required String token}) {
    return ApiService.get('/daily/creator/missions', token: token);
  }

  static Future<Map<String, dynamic>> claimCreatorMission({
    required String token,
    required String missionId,
  }) {
    return ApiService.post(
      '/daily/creator/missions/claim',
      token: token,
      data: {'missionId': missionId.trim()},
    );
  }

  static Future<Map<String, dynamic>> creatorLeaderboard({
    required String token,
    String period = 'weekly',
    int limit = 20,
  }) {
    final p = (period == 'monthly') ? 'monthly' : 'weekly';
    final l = limit.clamp(5, 100);
    return ApiService.get(
      '/daily/creator/leaderboard?period=$p&limit=$l',
      token: token,
    );
  }
}
