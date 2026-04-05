import 'api_service.dart';

class CreatorMonetizationService {
  static Future<Map<String, dynamic>> checkout({
    required String token,
    required String creatorUserId,
    required String type, // 'creator_pass' | 'tip'
    double? amountUsd,
    String? message,
  }) async {
    return ApiService.post(
      '/creator-monetization/checkout',
      token: token,
      data: {
        'creatorUserId': creatorUserId.trim(),
        'type': type,
        if (amountUsd != null) 'amountUsd': amountUsd,
        if (message != null) 'message': message,
      },
    );
  }

  static Future<Map<String, dynamic>> paymentSheet({
    required String token,
    required String creatorUserId,
    required String type, // 'creator_pass' | 'tip'
    double? amountUsd,
    String? message,
  }) async {
    return ApiService.post(
      '/creator-monetization/payment-sheet',
      token: token,
      data: {
        'creatorUserId': creatorUserId.trim(),
        'type': type,
        if (amountUsd != null) 'amountUsd': amountUsd,
        if (message != null) 'message': message,
      },
    );
  }

  static Future<Map<String, dynamic>> entitlement({
    required String token,
    required String creatorUserId,
  }) async {
    return ApiService.get(
      '/creator-monetization/creators/${Uri.encodeComponent(creatorUserId.trim())}/entitlement',
      token: token,
    );
  }

  static Future<Map<String, dynamic>> wallet({
    required String token,
  }) async {
    return ApiService.get('/creator-monetization/me/wallet', token: token);
  }

  static Future<Map<String, dynamic>> transactions({
    required String token,
    int limit = 20,
    String? cursor,
  }) async {
    final qp = <String, String>{
      'limit': limit.toString(),
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
    };
    final suffix = qp.isEmpty ? '' : ('?' + Uri(queryParameters: qp).query);
    return ApiService.get('/creator-monetization/me/transactions$suffix', token: token);
  }

  static Future<Map<String, dynamic>> onboardingLink({
    required String token,
  }) async {
    return ApiService.post('/creator-monetization/me/onboarding-link', token: token);
  }

  static Future<Map<String, dynamic>> confirmPaymentIntent({
    required String token,
    required String paymentIntentId,
  }) async {
    return ApiService.post(
      '/creator-monetization/payment-intent/confirm',
      token: token,
      data: {
        'paymentIntentId': paymentIntentId.trim(),
      },
    );
  }
}
