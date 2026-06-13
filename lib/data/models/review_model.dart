class ReviewModel {
  final String id;
  final String gameId;
  final String userId;
  final int rating;
  final String? comment;
  final String? username;
  final String? avatarUrl;
  final DateTime? createdAt;

  ReviewModel({
    required this.id,
    required this.gameId,
    required this.userId,
    required this.rating,
    this.comment,
    this.username,
    this.avatarUrl,
    this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['_id'] ?? '',
      gameId: json['gameId'] ?? '',
      userId: json['userId'] ?? '',
      rating: json['rating'] ?? 0,
      comment: json['comment'],
      username: json['username'],
      avatarUrl: json['avatarUrl'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'rating': rating,
      'comment': comment,
    };
  }
}
