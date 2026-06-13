import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/challenges_service.dart';
import '../../widgets/custom_back_button.dart';
import '../../widgets/mesh_gradient_bg.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ChallengeCreatedScreen extends StatefulWidget {
  final int score;
  const ChallengeCreatedScreen({super.key, required this.score});

  @override
  State<ChallengeCreatedScreen> createState() => _ChallengeCreatedScreenState();
}

class _ChallengeCreatedScreenState extends State<ChallengeCreatedScreen> {
  bool _isLoading = true;
  String? _challengeId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _createChallenge();
  }

  Future<void> _createChallenge() async {
    try {
      final p = context.read<AuthProvider>();
      if (p.token == null) throw Exception('Not authenticated');

      final challenge = await ChallengesService.createChallenge(
        token: p.token!,
        gameType: 'GameForge Quiz',
        scoreToBeat: widget.score,
      );

      if (mounted) {
        setState(() {
          _challengeId = challenge.challengeId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _copyLink() {
    if (_challengeId == null) return;
    final link = 'http://localhost:55514/#/challenge/$_challengeId';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard!')),
    );
  }

  void _shareLink() {
    if (_challengeId == null) return;
    final link = 'http://localhost:55514/#/challenge/$_challengeId';
    final box = context.findRenderObject() as RenderBox?;
    final origin = (box != null)
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromLTWH(0, 0, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height);
    Share.share(
      'Beat my score of ${widget.score} on GameForge Quiz! 🎮🔥\n$link',
      sharePositionOrigin: origin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: MeshGradientBg(
              colors: [
                Color(0xFF2E1B4E),
                Color(0xFF1B1B4E),
                Color(0xFF4E1B4E),
              ],
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      CustomBackButton(onPressed: () => context.go('/dashboard')),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => context.go('/dashboard'),
                        icon: const Icon(Icons.dashboard_rounded, color: Colors.white70),
                        label: Text('Dashboard', style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(child: Text(_error!, style: TextStyle(color: AppColors.error)))
                          : Center(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 600),
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppSpacing.xl),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: AppColors.primaryGradient,
                                            boxShadow: [
                                              BoxShadow(
                                                color: cs.primary.withOpacity(0.4),
                                                blurRadius: 32,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(Icons.share_rounded, size: 48, color: Colors.white),
                                        ).animate().scale(delay: 100.ms, duration: 600.ms, curve: Curves.easeOutBack),
                                        const SizedBox(height: AppSpacing.xxxl),
                                        Text(
                                          'Challenge Created! 🔥',
                                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                          textAlign: TextAlign.center,
                                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Share the link and dare your friend to beat your score.',
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                color: Colors.white70,
                                              ),
                                          textAlign: TextAlign.center,
                                        ).animate().fadeIn(delay: 300.ms),
                                        const SizedBox(height: AppSpacing.xxxl),
                                        Container(
                                          padding: const EdgeInsets.all(AppSpacing.xl),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(AppBorderRadius.large),
                                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                'GameForge Quiz',
                                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                      fontWeight: FontWeight.w900,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.sports_esports_rounded, color: Colors.white70, size: 20),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Your score: ${widget.score}',
                                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
                                        const SizedBox(height: AppSpacing.xxl),
                                        Container(
                                          padding: const EdgeInsets.all(AppSpacing.lg),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(AppBorderRadius.large),
                                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Challenge Code',
                                                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: AppSpacing.md),
                                              Container(
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                decoration: BoxDecoration(
                                                  color: Colors.black45,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: cs.primary.withOpacity(0.3)),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    _challengeId!,
                                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                          color: cs.primary,
                                                          letterSpacing: 8,
                                                          fontWeight: FontWeight.w900,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: AppSpacing.md),
                                              Text(
                                                'http://localhost:55514/#/challenge/$_challengeId',
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                                              ),
                                            ],
                                          ),
                                        ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
                                        const SizedBox(height: AppSpacing.xxl),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 16),
                                              backgroundColor: cs.primary,
                                              foregroundColor: Colors.white,
                                              elevation: 8,
                                              shadowColor: cs.primary.withOpacity(0.5),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            ),
                                            onPressed: _shareLink,
                                            icon: const Icon(Icons.share_rounded),
                                            label: const Text('Share Challenge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          ),
                                        ).animate().fadeIn(delay: 600.ms).scaleXY(begin: 0.9, curve: Curves.easeOutBack),
                                        const SizedBox(height: AppSpacing.md),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 16),
                                              foregroundColor: Colors.white,
                                              side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            ),
                                            onPressed: _copyLink,
                                            icon: const Icon(Icons.copy_rounded),
                                            label: const Text('Copy Link', style: TextStyle(fontSize: 16)),
                                          ),
                                        ).animate().fadeIn(delay: 700.ms),
                                        const SizedBox(height: AppSpacing.xxxl),
                                        TextButton.icon(
                                          style: TextButton.styleFrom(foregroundColor: cs.secondary),
                                          onPressed: () {
                                            context.push('/challenge/$_challengeId');
                                          },
                                          icon: const Icon(Icons.visibility_rounded),
                                          label: const Text('Preview "Accept Challenge" Screen'),
                                        ).animate().fadeIn(delay: 800.ms),
                                        const SizedBox(height: 40), // Extra padding at bottom for scroll bounce
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
