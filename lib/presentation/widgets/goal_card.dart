import 'dart:ui';
import 'package:flutter/material.dart';
import '../../data/models/goal_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GoalCard extends StatefulWidget {
  final GoalModel goal;
  final VoidCallback onTap;
  final VoidCallback onAddProgress;

  const GoalCard({
    super.key,
    required this.goal,
    required this.onTap,
    required this.onAddProgress,
  });

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percentage = widget.goal.completionPercentage;
    final isNearComplete = percentage >= 0.8 && percentage < 1.0;
    final isCompleted = percentage >= 1.0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isCompleted
                ? AppColors.primary.withOpacity(0.6)
                : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
            width: 1.5,
          ),
          boxShadow: [
            if (isCompleted)
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    isCompleted
                        ? AppColors.primary.withOpacity(0.15)
                        : (isDark ? const Color(0xFF1A1C29) : Colors.white).withOpacity(0.85),
                    isCompleted
                        ? AppColors.accent.withOpacity(0.05)
                        : (isDark ? const Color(0xFF12141D) : const Color(0xFFF8F9FC)).withOpacity(0.9),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? AppColors.primary.withOpacity(0.2)
                              : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                        ),
                        child: Icon(
                          isCompleted ? Icons.emoji_events_rounded : Icons.track_changes_rounded,
                          color: isCompleted ? AppColors.primary : (isDark ? Colors.white70 : Colors.black87),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.goal.title,
                              style: AppTypography.titleMedium.copyWith(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.goal.progress} / ${widget.goal.target}',
                              style: AppTypography.body2.copyWith(
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isCompleted)
                        IconButton(
                          onPressed: widget.onAddProgress,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Stack(
                    children: [
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        height: 10,
                        width: MediaQuery.of(context).size.width * 0.8 * percentage,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.accent, AppColors.primary],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isNearComplete)
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'You\'re ${(percentage * 100).toInt()}% done!',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Goal Completed!',
                                style: AppTypography.labelSmall.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const SizedBox(),
                      Text(
                        '${(percentage * 100).toInt()}%',
                        style: AppTypography.labelLarge.copyWith(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate(target: isCompleted ? 1 : 0).shimmer(duration: 2.seconds, blendMode: BlendMode.overlay, color: Colors.white24);
  }
}
