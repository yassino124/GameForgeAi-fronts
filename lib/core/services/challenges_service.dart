import '../../data/models/challenge_model.dart';
import 'api_service.dart';

class ChallengesService {
  static Future<ChallengeModel> createChallenge({
    required String token,
    required String gameType,
    required int scoreToBeat,
  }) async {
    try {
      final res = await ApiService.post(
        '/challenges',
        data: {
          'gameType': gameType,
          'scoreToBeat': scoreToBeat,
        },
        token: token,
      );

      if (res['success'] == true && res['data'] != null) {
        return ChallengeModel.fromJson(res['data']);
      }
      throw Exception('Failed to create challenge: ${res['message']}');
    } catch (e) {
      throw Exception('Failed to create challenge: $e');
    }
  }

  static Future<ChallengeModel> getChallengeDetails({
    required String token,
    required String challengeId,
  }) async {
    try {
      final res = await ApiService.get(
        '/challenges/$challengeId',
        token: token,
      );

      if (res['success'] == true && res['data'] != null) {
        return ChallengeModel.fromJson(res['data']);
      }
      throw Exception('Failed to fetch challenge: ${res['message']}');
    } catch (e) {
      throw Exception('Failed to fetch challenge: $e');
    }
  }
}
