import 'api_service.dart';

class WorldsService {
  /* ─── Discover public worlds ─── */
  static Future<Map<String, dynamic>> discoverWorlds({
    required String token,
    int limit = 20,
    int skip = 0,
  }) async {
    return ApiService.get('/worlds/discover?limit=$limit&skip=$skip', token: token);
  }

  /* ─── My worlds ─── */
  static Future<Map<String, dynamic>> myWorlds({required String token}) async {
    return ApiService.get('/worlds/mine', token: token);
  }

  /* ─── Get world by ID ─── */
  static Future<Map<String, dynamic>> getWorld({
    required String token,
    required String worldId,
  }) async {
    return ApiService.get('/worlds/$worldId', token: token);
  }

  /* ─── Create world ─── */
  static Future<Map<String, dynamic>> createWorld({
    required String token,
    required String name,
    required String theme,
    String? description,
    bool isPublic = true,
    bool allowNftCosmetics = false,
  }) async {
    return ApiService.post(
      '/worlds',
      token: token,
      data: {
        'name': name.trim(),
        'theme': theme,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'isPublic': isPublic,
        'allowNftCosmetics': allowNftCosmetics,
      },
    );
  }

  /* ─── Publish world ─── */
  static Future<Map<String, dynamic>> publishWorld({
    required String token,
    required String worldId,
  }) async {
    return ApiService.patch('/worlds/$worldId/publish', token: token);
  }

  /* ─── Delete world ─── */
  static Future<Map<String, dynamic>> deleteWorld({
    required String token,
    required String worldId,
  }) async {
    return ApiService.delete('/worlds/$worldId', token: token);
  }

  /* ─── Rate world ─── */
  static Future<Map<String, dynamic>> rateWorld({
    required String token,
    required String worldId,
    required double rating,
  }) async {
    return ApiService.post(
      '/worlds/$worldId/rate',
      token: token,
      data: {'rating': rating},
    );
  }

  /* ─── Add portal ─── */
  static Future<Map<String, dynamic>> addPortal({
    required String token,
    required String worldId,
    required String projectId,
    required String label,
  }) async {
    return ApiService.post(
      '/worlds/portal',
      token: token,
      data: {'worldId': worldId, 'projectId': projectId, 'label': label},
    );
  }

  /* ─── Remove portal ─── */
  static Future<Map<String, dynamic>> removePortal({
    required String token,
    required String worldId,
    required String projectId,
  }) async {
    return ApiService.delete('/worlds/$worldId/portal/$projectId', token: token);
  }

  /* ─── Start event ─── */
  static Future<Map<String, dynamic>> startEvent({
    required String token,
    required String worldId,
    required String type,
    required String label,
    int durationMinutes = 60,
  }) async {
    return ApiService.post(
      '/worlds/event',
      token: token,
      data: {
        'worldId': worldId,
        'type': type,
        'label': label,
        'durationMinutes': durationMinutes,
      },
    );
  }

  /* ─── OLLAMA AI: generate description ─── */
  static Future<String> generateDescription({
    required String worldName,
    required String theme,
    String model = 'llama3.2',
  }) async {
    try {
      final res = await ApiService.post(
        '/worlds/ai/describe',
        data: {'worldName': worldName, 'theme': theme, 'model': model},
      );
      final data = res['data'];
      if (data is String && data.trim().isNotEmpty) return data.trim();
      return '';
    } catch (_) {
      return '';
    }
  }

  /* ─── OLLAMA AI: event ideas ─── */
  static Future<List<String>> generateEventIdeas({
    required String worldName,
    required String theme,
    String model = 'llama3.2',
  }) async {
    try {
      final res = await ApiService.post(
        '/worlds/ai/events',
        data: {'worldName': worldName, 'theme': theme, 'model': model},
      );
      final data = res['data'];
      if (data is List) return data.map((e) => e.toString()).toList();
      return [];
    } catch (_) {
      return [];
    }
  }

  /* ─── OLLAMA AI: portal names ─── */
  static Future<List<String>> generatePortalNames({
    required String theme,
    int count = 5,
    String model = 'llama3.2',
  }) async {
    try {
      final res = await ApiService.post(
        '/worlds/ai/portals',
        data: {'theme': theme, 'count': count, 'model': model},
      );
      final data = res['data'];
      if (data is List) return data.map((e) => e.toString()).toList();
      return [];
    } catch (_) {
      return [];
    }
  }
}
