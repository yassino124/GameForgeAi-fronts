class ChallengeModel {
  final String challengeId;
  final String creatorId;
  final String? creatorName;
  final String? creatorAvatarUrl;
  final String gameType;
  final int scoreToBeat;
  final DateTime createdAt;

  ChallengeModel({
    required this.challengeId,
    required this.creatorId,
    this.creatorName,
    this.creatorAvatarUrl,
    required this.gameType,
    required this.scoreToBeat,
    required this.createdAt,
  });

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    final creator = json['creatorId'];
    String cId = '';
    String? cName;
    String? cAvatar;

    if (creator is Map) {
      cId = creator['_id']?.toString() ?? '';
      cName = creator['username']?.toString();
      cAvatar = creator['avatarUrl']?.toString();
    } else {
      cId = creator?.toString() ?? '';
    }

    return ChallengeModel(
      challengeId: json['challengeId']?.toString() ?? '',
      creatorId: cId,
      creatorName: cName,
      creatorAvatarUrl: cAvatar,
      gameType: json['gameType']?.toString() ?? 'GameForge Quiz',
      scoreToBeat: (json['scoreToBeat'] is num) ? (json['scoreToBeat'] as num).toInt() : 0,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
