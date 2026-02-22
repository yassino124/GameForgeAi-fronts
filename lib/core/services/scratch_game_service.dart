import 'api_service.dart';

/// Service for the AI "generate from scratch" feature.
class ScratchGameService {
  /// POST /ai/generate-gdd-preview
  /// Returns just the Game Design Document (for preview before building).
  static Future<Map<String, dynamic>> previewGdd({
    required String token,
    required String prompt,
  }) async {
    return ApiService.post(
      '/ai/generate-gdd-preview',
      token: token,
      data: {'prompt': prompt.trim()},
      timeout: const Duration(seconds: 60),
    );
  }

  /// POST /ai/generate-from-scratch
  /// Generates a full game (GDD + C# scripts + Unity build) from a text prompt.
  static Future<Map<String, dynamic>> generateFromScratch({
    required String token,
    required String prompt,
    String buildTarget = 'webgl',
  }) async {
    return ApiService.post(
      '/ai/generate-from-scratch',
      token: token,
      data: {
        'prompt': prompt.trim(),
        'buildTarget': buildTarget,
      },
      timeout: const Duration(seconds: 180),
    );
  }
}
