import 'api_service.dart';

class LiveService {
  static Future<Map<String, dynamic>> feed({
    required String token,
    int limit = 10,
    String? cursor,
  }) async {
    final qp = <String, String>{
      'limit': limit.toString(),
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
    };
    final suffix = qp.isEmpty ? '' : ('?' + Uri(queryParameters: qp).query);
    return ApiService.get('/live/feed$suffix', token: token);
  }

  static Future<Map<String, dynamic>> create({
    required String token,
    String? title,
    String? description,
    String? gameTitle,
    String? gameIcon,
  }) async {
    return ApiService.post(
      '/live/create',
      token: token,
      data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (gameTitle != null) 'gameTitle': gameTitle,
        if (gameIcon != null) 'gameIcon': gameIcon,
      },
    );
  }

  static Future<Map<String, dynamic>> end({
    required String token,
    required String liveId,
  }) async {
    return ApiService.post('/live/$liveId/end', token: token);
  }

  static Future<Map<String, dynamic>> join({
    required String token,
    required String liveId,
  }) async {
    return ApiService.post('/live/$liveId/join', token: token);
  }

  // Stripe Gifts
  static Future<Map<String, dynamic>> createGiftPaymentSheet({
    required String token,
    required double amount,
  }) async {
    return ApiService.post(
      '/billing/gift-payment-sheet',
      token: token,
      data: {'amount': amount},
    );
  }
}
