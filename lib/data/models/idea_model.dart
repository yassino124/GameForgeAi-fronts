class IdeaExpandedData {
  final List<String> features;
  final String targetAudience;
  final List<String> monetization;
  final List<String> roadmap;
  final List<String> contentIdeas;

  IdeaExpandedData({
    required this.features,
    required this.targetAudience,
    required this.monetization,
    required this.roadmap,
    required this.contentIdeas,
  });

  factory IdeaExpandedData.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic list) {
      if (list is! List) return [];
      return list.map((e) {
        if (e is Map) {
          // Attempt to extract meaningful fields from Ollama's returned JSON objects
          final title = e['name'] ?? e['title'] ?? e['step'] ?? e['feature'] ?? '';
          final desc = e['description'] ?? e['details'] ?? e['content'] ?? '';
          
          if (title.toString().isNotEmpty && desc.toString().isNotEmpty) {
            return '${title.toString()}: ${desc.toString()}';
          } else if (title.toString().isNotEmpty) {
            return title.toString();
          } else if (desc.toString().isNotEmpty) {
            return desc.toString();
          }
          return e.toString();
        }
        return e.toString();
      }).toList();
    }

    return IdeaExpandedData(
      features: parseList(json['features']),
      targetAudience: json['targetAudience']?.toString() ?? '',
      monetization: parseList(json['monetization']),
      roadmap: parseList(json['roadmap']),
      contentIdeas: parseList(json['contentIdeas']),
    );
  }
}

class IdeaModel {
  final String id;
  final String title;
  final String description;
  final List<String> tags;
  final bool favorite;
  final IdeaExpandedData? expandedData;
  final String? imageUrl;
  final DateTime createdAt;

  IdeaModel({
    required this.id,
    required this.title,
    required this.description,
    required this.tags,
    required this.favorite,
    this.expandedData,
    this.imageUrl,
    required this.createdAt,
  });

  factory IdeaModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic list) {
      if (list is! List) return [];
      return list.map((e) => e.toString()).toList();
    }
    return IdeaModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      tags: parseList(json['tags']),
      favorite: json['favorite'] ?? false,
      expandedData: json['expandedData'] != null ? IdeaExpandedData.fromJson(json['expandedData']) : null,
      imageUrl: json['imageUrl']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now(),
    );
  }
}
