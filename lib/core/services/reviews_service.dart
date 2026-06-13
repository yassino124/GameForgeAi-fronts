import '../../data/models/review_model.dart';
import 'api_service.dart';

class ReviewsService {
  static Future<ReviewModel> submitReview({
    required String token,
    required String gameId,
    required int rating,
    String? comment,
  }) async {
    final res = await ApiService.post(
      '/reviews',
      token: token,
      data: {
        'gameId': gameId,
        'rating': rating,
        'comment': comment,
      },
    );
    
    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to submit review');
    }
    
    return ReviewModel.fromJson(res['data']);
  }

  static Future<List<ReviewModel>> getReviews({
    required String token,
    required String gameId,
  }) async {
    final res = await ApiService.get(
      '/reviews/$gameId',
      token: token,
    );
    
    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to fetch reviews');
    }
    
    final List data = res['data'] ?? [];
    return data.map((e) => ReviewModel.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> analyzeReviews({
    required String token,
    required String gameId,
  }) async {
    final res = await ApiService.post(
      '/reviews/$gameId/analyze',
      token: token,
    );
    
    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to analyze reviews');
    }
    
    return res['data'] ?? {};
  }
}
