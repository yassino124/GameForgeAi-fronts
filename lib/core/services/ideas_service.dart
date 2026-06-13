import '../../data/models/idea_model.dart';
import 'api_service.dart';

class IdeasService {
  static Future<List<IdeaModel>> getIdeas({required String token}) async {
    try {
      final response = await ApiService.get(
        '/ideas',
        token: token,
      );
      if (response['data'] is List) {
        return (response['data'] as List).map((json) => IdeaModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load ideas: $e');
    }
  }

  static Future<IdeaModel> createIdea({
    required String token,
    required String title,
    required String description,
    required List<String> tags,
  }) async {
    try {
      final response = await ApiService.post(
        '/ideas',
        token: token,
        data: {
          'title': title,
          'description': description,
          'tags': tags,
        },
      );
      if (response['data'] != null) {
        return IdeaModel.fromJson(response['data']);
      }
      throw Exception('Failed to create idea');
    } catch (e) {
      throw Exception('Failed to create idea: $e');
    }
  }

  static Future<IdeaModel> toggleFavorite({
    required String token,
    required String ideaId,
    required bool favorite,
  }) async {
    try {
      final response = await ApiService.put(
        '/ideas/$ideaId',
        token: token,
        data: {'favorite': favorite},
      );
      if (response['data'] != null) {
        return IdeaModel.fromJson(response['data']);
      }
      throw Exception('Failed to toggle favorite');
    } catch (e) {
      throw Exception('Failed to update idea: $e');
    }
  }

  static Future<IdeaModel> expandIdeaWithAI({
    required String token,
    required String ideaId,
  }) async {
    try {
      final response = await ApiService.post(
        '/ideas/$ideaId/expand',
        token: token,
      );
      if (response['data'] != null) {
        return IdeaModel.fromJson(response['data']);
      }
      throw Exception('Failed to expand idea');
    } catch (e) {
      throw Exception('Failed to expand idea with AI: $e');
    }
  }

  static Future<IdeaModel> generateIdeaImage({
    required String token,
    required String ideaId,
  }) async {
    try {
      final response = await ApiService.post(
        '/ideas/$ideaId/generate-image',
        token: token,
      );
      if (response['data'] != null) {
        return IdeaModel.fromJson(response['data']);
      }
      throw Exception('Failed to generate image');
    } catch (e) {
      throw Exception('Failed to generate AI image: $e');
    }
  }

  static Future<IdeaModel> updateIdea({
    required String token,
    required String ideaId,
    String? title,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (imageUrl != null) data['imageUrl'] = imageUrl;

      final response = await ApiService.put(
        '/ideas/$ideaId',
        token: token,
        data: data,
      );
      if (response['data'] != null) {
        return IdeaModel.fromJson(response['data']);
      }
      throw Exception('Failed to update idea');
    } catch (e) {
      throw Exception('Failed to update idea: $e');
    }
  }
}
