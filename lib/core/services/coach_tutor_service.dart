import 'api_service.dart';

class CoachTutorService {
  static Future<Map<String, dynamic>> tutor({
    required String token,
    String? gameId,
    String? projectId,
    String? gameType,
    String? userStyle,
    Map<String, dynamic>? run,
    List<dynamic>? lastRuns,
    Map<String, dynamic>? currentConfig,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    return ApiService.post(
      '/coach/tutor',
      token: token,
      timeout: timeout,
      data: {
        if (gameId != null && gameId.trim().isNotEmpty) 'gameId': gameId.trim(),
        if (projectId != null && projectId.trim().isNotEmpty)
          'projectId': projectId.trim(),
        if (gameType != null && gameType.trim().isNotEmpty)
          'gameType': gameType.trim(),
        if (userStyle != null && userStyle.trim().isNotEmpty)
          'userStyle': userStyle.trim(),
        if (run != null) 'run': run,
        if (lastRuns != null) 'lastRuns': lastRuns,
        if (currentConfig != null) 'currentConfig': currentConfig,
      },
    );
  }
}
