import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/challenges_service.dart';
import '../../../data/models/challenge_model.dart';
import '../../widgets/custom_back_button.dart';
import '../../widgets/mesh_gradient_bg.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ChallengeAcceptScreen extends StatefulWidget {
  final String challengeId;
  const ChallengeAcceptScreen({super.key, required this.challengeId});

  @override
  State<ChallengeAcceptScreen> createState() => _ChallengeAcceptScreenState();
}

class _ChallengeAcceptScreenState extends State<ChallengeAcceptScreen> {
  bool _isLoading = true;
  ChallengeModel? _challenge;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChallenge();
  }

  Future<void> _loadChallenge() async {
    try {
      final p = context.read<AuthProvider>();
      if (p.token == null) {
        // Allow unauthenticated users to see the challenge, but prompt them to log in when clicking play
        // However, ChallengesService requires a token. We might need a public endpoint.
        // For now, if no token, redirect to login with a deep link? Or just try?
        // Assuming user is logged in:
        if (p.token == null) {
          throw Exception('Please log in first to accept challenges.');
        }
      }

      final challenge = await ChallengesService.getChallengeDetails(
        token: p.token!,
        challengeId: widget.challengeId,
      );

      if (mounted) {
        setState(() {
          _challenge = challenge;
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
                Color(0xFF0F2027),
                Color(0xFF203A43),
                Color(0xFF2C5364),
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
                      CustomBackButton(onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      }),
                      const SizedBox(width: AppSpacing.md),
                      Text('Challenge', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : _error != null
                                ? Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(color: cs.error.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                                    child: Text(_error!, style: TextStyle(color: cs.error, fontSize: 16)),
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(AppSpacing.xxl),
                                        decoration: BoxDecoration(
                                          color: cs.surface.withOpacity(0.85),
                                          borderRadius: BorderRadius.circular(AppBorderRadius.xlarge),
                                          border: Border.all(color: cs.primary.withOpacity(0.5), width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: cs.primary.withOpacity(0.2),
                                              blurRadius: 32,
                                              spreadRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(color: cs.primary.withOpacity(0.5), blurRadius: 16, spreadRadius: 4),
                                                    ],
                                                  ),
                                                  child: CircleAvatar(
                                                    radius: 36,
                                                    backgroundColor: cs.primary.withOpacity(0.2),
                                                    backgroundImage: _challenge?.creatorAvatarUrl != null
                                                        ? NetworkImage(_challenge!.creatorAvatarUrl!)
                                                        : null,
                                                    child: _challenge?.creatorAvatarUrl == null
                                                        ? Icon(Icons.person, color: cs.primary, size: 36)
                                                        : null,
                                                  ),
                                                ),
                                                const SizedBox(width: AppSpacing.xl),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        _challenge?.creatorName ?? 'Unknown User',
                                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                                              fontWeight: FontWeight.w900,
                                                              color: Colors.white,
                                                            ),
                                                      ),
                                                      Text(
                                                        'has challenged you!',
                                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                              color: cs.primary,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: AppSpacing.xxl),
                                            Container(
                                              padding: const EdgeInsets.all(AppSpacing.xl),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.4),
                                                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                                                border: Border.all(color: Colors.white12),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Game Mode',
                                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white54),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        _challenge?.gameType ?? 'GameForge Quiz',
                                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.w900,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        'Score to beat',
                                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white54),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        '${_challenge?.scoreToBeat ?? 0}',
                                                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                                              color: cs.primary,
                                                              fontWeight: FontWeight.w900,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack).fadeIn(duration: 400.ms),
                                      const SizedBox(height: AppSpacing.xxxl),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 20),
                                            backgroundColor: cs.primary,
                                            foregroundColor: Colors.white,
                                            elevation: 12,
                                            shadowColor: cs.primary.withOpacity(0.8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          ),
                                          onPressed: () {
                                            context.pushReplacement('/game-quiz?challengeId=${_challenge!.challengeId}&scoreToBeat=${_challenge!.scoreToBeat}');
                                          },
                                          icon: const Icon(Icons.bolt_rounded, size: 32),
                                          label: const Text('ACCEPT CHALLENGE', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                                        ),
                                      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                                       .scaleXY(end: 1.05, duration: 1000.ms, curve: Curves.easeInOut),
                                    ],
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
