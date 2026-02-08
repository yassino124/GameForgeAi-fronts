import 'api_service.dart';

class BillingService {
  static Future<Map<String, dynamic>> getStripeConfig() async {
    return ApiService.get('/billing/config');
  }

  static Future<Map<String, dynamic>> getPlans() async {
    return ApiService.get('/billing/plans');
  }

  static Future<Map<String, dynamic>> getMySubscription({required String token}) async {
    return ApiService.get('/billing/subscription', token: token);
  }

  static Future<Map<String, dynamic>> createCheckoutSession({
    required String token,
    required String priceId,
  }) async {
    return ApiService.post(
      '/billing/checkout',
      token: token,
      data: {
        'priceId': priceId,
      },
    );
  }

  static Future<Map<String, dynamic>> createCustomerPortalSession({
    required String token,
  }) async {
    return ApiService.post('/billing/portal', token: token);
  }

  static Future<Map<String, dynamic>> createPaymentSheet({
    required String token,
    required String priceId,
  }) async {
    return ApiService.post(
      '/billing/payment-sheet',
      token: token,
      data: {
        'priceId': priceId,
      },
    );
  }

  static Future<Map<String, dynamic>> cancelSubscription({
    required String token,
  }) async {
    return ApiService.post('/billing/cancel-subscription', token: token);
  }
}
