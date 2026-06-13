import '../../data/models/goal_model.dart';
import 'api_service.dart';

class GoalsService {
  static Future<List<GoalModel>> getGoals({required String token}) async {
    try {
      final res = await ApiService.get(
        '/goals',
        token: token,
      );
      if (res['success'] == true && res['data'] is List) {
        return (res['data'] as List).map((e) => GoalModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load goals: $e');
    }
  }

  static Future<GoalModel> createGoal({required String token, required String title, required int target}) async {
    try {
      final res = await ApiService.post(
        '/goals',
        data: {'title': title, 'target': target},
        token: token,
      );
      if (res['success'] == true && res['data'] != null) {
        return GoalModel.fromJson(res['data']);
      }
      throw Exception('Failed to create goal');
    } catch (e) {
      throw Exception('Failed to create goal: $e');
    }
  }

  static Future<GoalModel> updateProgress({required String token, required String goalId, required int progress}) async {
    try {
      final res = await ApiService.patch(
        '/goals/$goalId/progress',
        data: {'progress': progress},
        token: token,
      );
      if (res['success'] == true && res['data'] != null) {
        return GoalModel.fromJson(res['data']);
      }
      throw Exception('Failed to update goal');
    } catch (e) {
      throw Exception('Failed to update goal: $e');
    }
  }

  static Future<void> deleteGoal({required String token, required String goalId}) async {
    try {
      await ApiService.delete(
        '/goals/$goalId',
        token: token,
      );
    } catch (e) {
      throw Exception('Failed to delete goal: $e');
    }
  }
}
