import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/goals_service.dart';
import '../../../data/models/goal_model.dart';
import '../../widgets/goal_card.dart';
import '../../widgets/mesh_gradient_bg.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _bgAnimation;
  List<GoalModel> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _bgAnimation = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
    _loadGoals();
  }

  @override
  void dispose() {
    _bgAnimation.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      if (token != null) {
        final goals = await GoalsService.getGoals(token: token);
        setState(() => _goals = goals);
      }
    } catch (e) {
      debugPrint('Error loading goals: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddGoalDialog() async {
    final titleController = TextEditingController();
    final targetController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E2A) : Colors.white,
          title: Text('New Goal', style: AppTypography.titleMedium.copyWith(color: isDark ? Colors.white : Colors.black)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Goal Title (e.g., Reach 10k users)',
                  labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Target Number',
                  labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final targetText = targetController.text.replaceAll(RegExp(r'[^0-9]'), '');
                final target = int.tryParse(targetText) ?? 0;
                
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a goal title.'), backgroundColor: Colors.orange),
                  );
                  return;
                }
                if (target <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid target number.'), backgroundColor: Colors.orange),
                  );
                  return;
                }

                Navigator.pop(context);
                await _createGoal(title, target);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createGoal(String title, int target) async {
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      if (token != null) {
        await GoalsService.createGoal(token: token, title: title, target: target);
        _loadGoals();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Goal "$title" created!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating goal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create goal.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addProgress(GoalModel goal) async {
    HapticFeedback.lightImpact();
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      if (token != null) {
        await GoalsService.updateProgress(token: token, goalId: goal.id, progress: goal.progress + 1);
        _loadGoals();
      }
    } catch (e) {
      debugPrint('Error updating goal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update progress.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark mode aesthetic base
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Premium Mesh Gradient Background
          Positioned.fill(
            child: MeshGradientBg(
              colors: [
                const Color(0xFF0F172A), // Deep blue-gray
                AppColors.primary.withOpacity(0.3),
                AppColors.secondary.withOpacity(0.2),
                const Color(0xFF000000),
              ],
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'My Goals',
                        style: AppTypography.h2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 12, spreadRadius: 2)],
                        ),
                        child: IconButton(
                          onPressed: _showAddGoalDialog,
                          icon: const Icon(Icons.add_rounded),
                          color: Colors.white,
                          iconSize: 28,
                        ),
                      ).animate().fadeIn(delay: 200.ms).scale(),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : _goals.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              physics: const BouncingScrollPhysics(),
                              itemCount: _goals.length,
                              itemBuilder: (context, index) {
                                final goal = _goals[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: GoalCard(
                                    goal: goal,
                                    onTap: () {},
                                    onAddProgress: () => _addProgress(goal),
                                  ),
                                ).animate().fadeIn(delay: (100 * index).ms).slideY(begin: 0.2);
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Icon(
              Icons.flag_rounded,
              size: 80,
              color: Colors.white54,
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.05, duration: 2.seconds),
          const SizedBox(height: 24),
          Text(
            'No goals set yet.',
            style: AppTypography.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 8),
          Text(
            'Create your first goal to track progress!',
            style: AppTypography.body2.copyWith(color: Colors.white60),
          ).animate().fadeIn(delay: 500.ms),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8))],
            ),
            child: ElevatedButton.icon(
              onPressed: _showAddGoalDialog,
              icon: const Icon(Icons.rocket_launch_rounded),
              label: const Text('Launch a Goal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }
}
