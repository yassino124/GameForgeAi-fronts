import 'api_service.dart';
import 'dart:io';

class GameFeedService {
  static Future<Map<String, dynamic>> list({
    required String token,
    int limit = 10,
    String? cursor,
  }) async {
    final qp = <String, String>{
      'limit': limit.toString(),
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
    };
    final suffix = qp.isEmpty ? '' : ('?' + Uri(queryParameters: qp).query);
    return ApiService.get('/game-feed$suffix', token: token);
  }

  static Future<Map<String, dynamic>> publish({
    required String token,
    required String projectId,
    String? title,
    String? description,
    List<String>? tags,
  }) async {
    return ApiService.post(
      '/game-feed/publish',
      token: token,
      data: {
        'projectId': projectId.trim(),
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (tags != null) 'tags': tags,
      },
    );
  }

  static Future<Map<String, dynamic>> like({
    required String token,
    required String postId,
  }) async {
    return ApiService.post('/game-feed/$postId/like', token: token);
  }

  static Future<Map<String, dynamic>> unlike({
    required String token,
    required String postId,
  }) async {
    return ApiService.post('/game-feed/$postId/unlike', token: token);
  }

  static Future<Map<String, dynamic>> remix({
    required String token,
    required String postId,
  }) async {
    return ApiService.post('/game-feed/$postId/remix', token: token);
  }

  static Future<Map<String, dynamic>> play({
    required String token,
    required String postId,
  }) async {
    return ApiService.post('/game-feed/$postId/play', token: token);
  }

  static Future<Map<String, dynamic>> share({
    required String token,
    required String postId,
  }) async {
    return ApiService.post('/game-feed/$postId/share', token: token);
  }

  static Future<Map<String, dynamic>> listComments({
    required String token,
    required String postId,
    int limit = 20,
    String? cursor,
  }) async {
    final qp = <String, String>{
      'limit': limit.toString(),
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
    };
    final suffix = qp.isEmpty ? '' : ('?' + Uri(queryParameters: qp).query);
    return ApiService.get('/game-feed/$postId/comments$suffix', token: token);
  }

  static Future<Map<String, dynamic>> addComment({
    required String token,
    required String postId,
    required String text,
  }) async {
    return ApiService.post(
      '/game-feed/$postId/comments',
      token: token,
      data: {
        'text': text.trim(),
      },
    );
  }

  static Future<Map<String, dynamic>> addAudioComment({
    required String token,
    required String postId,
    required File file,
    int? durationMs,
  }) async {
    return ApiService.multipart(
      '/game-feed/$postId/comments/audio',
      method: 'POST',
      token: token,
      file: file,
      fileField: 'file',
      fields: {
        if (durationMs != null) 'durationMs': durationMs.toString(),
      },
    );
  }
}
