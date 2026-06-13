import 'api_service.dart';

class TournamentsService {
  static Future<Map<String, dynamic>> createTournament({
    required String token,
    required String creatorId,
    required String gameId,
    required String title,
    String mode = 'ranked',
    String? seasonId,
    int? entryFee,
    int? maxPlayers,
    String? coverImageUrl,
    Map<String, dynamic>? gameConfig,
  }) {
    return ApiService.post(
      '/platform-labs/tournaments/create',
      token: token,
      data: {
        'creatorId': creatorId.trim(),
        'gameId': gameId.trim(),
        'title': title.trim(),
        if (mode.trim().isNotEmpty) 'mode': mode.trim(),
        if (seasonId != null && seasonId.trim().isNotEmpty)
          'seasonId': seasonId.trim(),
        if (entryFee != null) 'entryFee': entryFee,
        if (maxPlayers != null) 'maxPlayers': maxPlayers,
        if (coverImageUrl != null && coverImageUrl.trim().isNotEmpty)
          'coverImageUrl': coverImageUrl.trim(),
        if (gameConfig != null && gameConfig.isNotEmpty) 'gameConfig': gameConfig,
      },
    );
  }

  static Future<Map<String, dynamic>> listTournaments({
    required String token,
    required String status,
    String? userId,
  }) {
    final qp = <String, String>{
      'status': status.trim().isEmpty ? 'active' : status.trim(),
      if (userId != null && userId.trim().isNotEmpty) 'userId': userId.trim(),
    };
    final uri = Uri(path: '/platform-labs/tournaments', queryParameters: qp);
    return ApiService.get(uri.toString(), token: token);
  }

  static Future<Map<String, dynamic>> wallet({
    required String token,
    required String userId,
  }) {
    return ApiService.get(
      '/platform-labs/tournaments/wallet/${userId.trim()}',
      token: token,
    );
  }

  static Future<Map<String, dynamic>> topUpCheckout({
    required String token,
    required String userId,
    required double amountUsd,
    String? successUrl,
    String? cancelUrl,
  }) {
    return ApiService.post(
      '/platform-labs/tournaments/wallet/top-up/checkout',
      token: token,
      data: {
        'userId': userId.trim(),
        'amountUsd': amountUsd,
        if (successUrl != null && successUrl.trim().isNotEmpty)
          'successUrl': successUrl.trim(),
        if (cancelUrl != null && cancelUrl.trim().isNotEmpty)
          'cancelUrl': cancelUrl.trim(),
      },
    );
  }

  static Future<Map<String, dynamic>> topUpPaymentIntent({
    required String token,
    required String userId,
    required double amountUsd,
  }) {
    return ApiService.post(
      '/platform-labs/tournaments/wallet/top-up/payment-intent',
      token: token,
      data: {
        'userId': userId.trim(),
        'amountUsd': amountUsd,
      },
    );
  }

  static Future<Map<String, dynamic>> confirmTopUpPaymentIntent({
    required String token,
    required String paymentIntentId,
    String? userId,
  }) {
    return ApiService.post(
      '/platform-labs/tournaments/wallet/top-up/payment-intent/confirm',
      token: token,
      data: {
        'paymentIntentId': paymentIntentId.trim(),
        if (userId != null && userId.trim().isNotEmpty) 'userId': userId.trim(),
      },
    );
  }

  static Future<Map<String, dynamic>> getTournament({
    required String token,
    required String tournamentId,
  }) {
    return ApiService.get('/platform-labs/tournaments/${Uri.encodeComponent(tournamentId)}', token: token);
  }

  static Future<Map<String, dynamic>> join({
    required String token,
    required String tournamentId,
    required String userId,
    required String playerName,
    int initialBalance = 5000,
  }) {
    return ApiService.post(
      '/platform-labs/tournaments/join',
      token: token,
      data: {
        'tournamentId': tournamentId.trim(),
        'userId': userId.trim(),
        'playerName': playerName.trim(),
        'initialBalance': initialBalance,
      },
    );
  }

  static Future<Map<String, dynamic>> playUrl({
    required String token,
    required String tournamentId,
  }) {
    return ApiService.get(
      '/platform-labs/tournaments/${Uri.encodeComponent(tournamentId)}/play-url',
      token: token,
    );
  }

  static Future<Map<String, dynamic>> submitScore({
    required String token,
    required String tournamentId,
    required String userId,
    required String playerName,
    required int score,
    int durationSec = 0,
    bool spectate = false,
  }) {
    return ApiService.post(
      '/platform-labs/tournaments/submit-score',
      token: token,
      data: {
        'tournamentId': tournamentId.trim(),
        'userId': userId.trim(),
        'playerName': playerName.trim(),
        'score': score,
        'durationSec': durationSec,
        if (spectate) 'spectate': true,
      },
    );
  }
}
