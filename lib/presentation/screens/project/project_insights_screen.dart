import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/reviews_service.dart';
import '../../widgets/mesh_gradient_bg.dart';

class ProjectInsightsScreen extends StatefulWidget {
  final String gameId;
  final String gameName;

  const ProjectInsightsScreen({super.key, required this.gameId, required this.gameName});

  @override
  State<ProjectInsightsScreen> createState() => _ProjectInsightsScreenState();
}

class _ProjectInsightsScreenState extends State<ProjectInsightsScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _insights;

  @override
  void initState() {
    super.initState();
    _fetchInsights();
  }

  Future<void> _fetchInsights() async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final token = context.read<AuthProvider>().token;
      if (token == null) throw Exception('Please log in.');

      final insights = await ReviewsService.analyzeReviews(
        token: token,
        gameId: widget.gameId,
      );

      if (mounted) {
        setState(() {
          _insights = insights;
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
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${widget.gameName} Insights 🧠', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Premium Mesh Gradient Background
          Positioned.fill(
            child: MeshGradientBg(
              colors: [
                const Color(0xFF0F1A2A),
                AppColors.primary.withOpacity(0.2),
                AppColors.secondary.withOpacity(0.3),
                Colors.black,
              ],
            ),
          ),
          SafeArea(
            child: _isLoading
                ? _buildLoading()
                : _error != null
                    ? _buildError()
                    : _buildInsights(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.secondary.withOpacity(0.8),
                      AppColors.primary.withOpacity(0.1),
                    ],
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat()).rotate(duration: 2.seconds),
              Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F1A2A),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 30, spreadRadius: 5),
                  ],
                ),
                child: const Icon(Icons.psychology_rounded, size: 52, color: Colors.white),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.1, duration: 1.seconds).shimmer(duration: 1.seconds, color: AppColors.secondary),
            ],
          ),
          const SizedBox(height: 32),
          const Text('ANALYZING PLAYER SENTIMENTS...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds, color: AppColors.primary),
          const SizedBox(height: 8),
          const Text('Ollama is extracting insights', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 64),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error?.replaceAll('Exception: ', '') ?? 'Unknown error', 
              style: const TextStyle(color: Colors.white, fontSize: 16), 
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchInsights,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildInsights() {
    final summary = _insights?['summary'] ?? 'No summary available.';
    final insights = (_insights?['actionableInsights'] as List?)?.cast<String>() ?? [];
    final imageUrl = _insights?['imageUrl'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // AI Generated Cover Image
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 2),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 30, spreadRadius: 2),
                      BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl.startsWith('data:image')
                          ? Image.memory(base64Decode(imageUrl.split(',').last), fit: BoxFit.cover)
                          : Image.network(imageUrl, fit: BoxFit.cover),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16, left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: AppColors.primary, size: 14),
                              SizedBox(width: 6),
                              Text('AI GENERATED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            ],
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 3.seconds),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),
          const SizedBox(height: 32),

          // Sentiment Summary
          _buildGlassCard(
            title: 'Player Sentiment',
            icon: Icons.psychology_rounded,
            child: Text(
              summary,
              style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.5, fontStyle: FontStyle.italic),
            ),
          ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
          const SizedBox(height: 24),

          // Actionable Insights
          _buildGlassCard(
            title: 'Actionable Suggestions',
            icon: Icons.lightbulb_outline_rounded,
            child: Column(
              children: insights.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text('${entry.key + 1}', style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required String title, required IconData icon, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withOpacity(0.05), blurRadius: 20, spreadRadius: 2),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
