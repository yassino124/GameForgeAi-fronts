import 'api_service.dart';

class AdsService {
  static Future<Map<String, dynamic>> active({
    required String token,
  }) async {
    return ApiService.get('/ads/active', token: token);
  }

  static Future<Map<String, dynamic>> track({
    required String token,
    required String campaignId,
    required String type, // 'impression' | 'click'
    String? postId,
    String? creditedCreatorUserId,
    String? deviceId,
  }) async {
    return ApiService.post(
      '/ads/${Uri.encodeComponent(campaignId.trim())}/track?type=${Uri.encodeQueryComponent(type)}',
      token: token,
      data: {
        if (postId != null) 'postId': postId,
        if (creditedCreatorUserId != null) 'creditedCreatorUserId': creditedCreatorUserId,
        if (deviceId != null) 'deviceId': deviceId,
      },
    );
  }
}
