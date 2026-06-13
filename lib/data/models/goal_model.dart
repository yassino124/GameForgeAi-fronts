class GoalModel {
  final String id;
  final String userId;
  final String title;
  final int progress;
  final int target;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GoalModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.progress,
    required this.target,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      title: json['title'] ?? '',
      progress: json['progress'] is num ? (json['progress'] as num).toInt() : 0,
      target: json['target'] is num ? (json['target'] as num).toInt() : 1,
      status: json['status'] ?? 'in-progress',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'title': title,
      'progress': progress,
      'target': target,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  double get completionPercentage => target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;
}
