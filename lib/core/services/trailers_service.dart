import 'api_service.dart';

class TrailersService {
  static Future<Map<String, dynamic>> createTrailer({
    required String token,
    required String projectId,
    String? sourceVideoUrl,
    String style = 'energetic',
    String target = 'tiktok',
    List<Map<String, dynamic>>? events,
  }) {
    return ApiService.post(
      '/trailers',
      token: token,
      data: {
        'projectId': projectId.trim(),
        if (sourceVideoUrl != null && sourceVideoUrl.trim().isNotEmpty)
          'sourceVideoUrl': sourceVideoUrl.trim(),
        'style': style,
        'target': target,
        if (events != null) 'events': events,
      },
      timeout: const Duration(seconds: 45),
    );
  }

  static Future<Map<String, dynamic>> publishTrailerToFeed({
    required String token,
    required String trailerId,
  }) {
    return ApiService.post('/trailers/$trailerId/publish-feed', token: token);
  }

  static Future<Map<String, dynamic>> getTrailerStatus({
    required String token,
    required String trailerId,
  }) {
    return ApiService.get('/trailers/$trailerId', token: token);
  }

  static Future<Map<String, dynamic>> getTrailerResult({
    required String token,
    required String trailerId,
  }) {
    return ApiService.get('/trailers/$trailerId/result', token: token);
  }
}
