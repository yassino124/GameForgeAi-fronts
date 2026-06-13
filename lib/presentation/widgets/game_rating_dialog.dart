import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/reviews_service.dart';

class GameRatingDialog extends StatefulWidget {
  final String gameId;

  const GameRatingDialog({super.key, required this.gameId});

  @override
  State<GameRatingDialog> createState() => _GameRatingDialogState();
}

class _GameRatingDialogState extends State<GameRatingDialog> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  void _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) throw Exception('Please log in to rate.');

      await ReviewsService.submitReview(
        token: token,
        gameId: widget.gameId,
        rating: _rating,
        comment: _commentController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback! 🚀'), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Widget _buildStar(int index) {
    bool isSelected = index <= _rating;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _rating = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: isSelected ? [
              BoxShadow(color: Colors.amberAccent.withOpacity(0.5), blurRadius: 20, spreadRadius: 2),
              BoxShadow(color: Colors.orangeAccent.withOpacity(0.3), blurRadius: 40, spreadRadius: 8),
            ] : [],
          ),
          child: Icon(
            isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 42,
            color: isSelected ? Colors.amberAccent : Colors.white24,
          ).animate(target: isSelected ? 1 : 0).scaleXY(begin: 1.0, end: 1.3, duration: 300.ms, curve: Curves.easeOutBack),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E1E2A).withOpacity(0.9),
                  const Color(0xFF0F1A2A).withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 40, spreadRadius: -5),
                BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 50, spreadRadius: 10),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 30, spreadRadius: 5),
                      BoxShadow(color: AppColors.secondary.withOpacity(0.3), blurRadius: 50, spreadRadius: 10),
                    ],
                    border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 2),
                  ),
                  child: const Icon(Icons.stars_rounded, color: Colors.white, size: 52),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.05, duration: 2.seconds).shimmer(duration: 2.seconds),
                const SizedBox(height: 24),
                const Text(
                  'Rate this Game',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your feedback helps AI generate better insights for the creator!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (index) => _buildStar(index + 1)),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 20, spreadRadius: 2),
                      BoxShadow(color: AppColors.secondary.withOpacity(0.05), blurRadius: 30, spreadRadius: 5),
                    ],
                  ),
                  child: TextField(
                    controller: _commentController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'What did you think? (too fast, fun, hard...)',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Submit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).scaleXY(begin: 0.9, end: 1.0, curve: Curves.easeOutBack);
  }
}
