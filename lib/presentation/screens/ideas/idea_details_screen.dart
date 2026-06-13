import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/ideas_service.dart';
import '../../../data/models/idea_model.dart';
import '../../widgets/custom_back_button.dart';
import '../../widgets/mesh_gradient_bg.dart';
import '../project/project_insights_screen.dart';

class IdeaDetailsScreen extends StatefulWidget {
  final String ideaId;
  const IdeaDetailsScreen({super.key, required this.ideaId});

  @override
  State<IdeaDetailsScreen> createState() => _IdeaDetailsScreenState();
}

class _IdeaDetailsScreenState extends State<IdeaDetailsScreen> {
  bool _isLoading = true;
  bool _isExpanding = false;
  bool _isGeneratingImage = false;
  IdeaModel? _idea;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIdea();
  }

  Future<void> _loadIdea() async {
    try {
      final auth = context.read<AuthProvider>();
      if (auth.token == null) throw Exception('Please log in.');

      // We don't have a get single idea endpoint yet, so fetch all and filter
      // Alternatively, we added GET /ideas/:id in the backend, let's use it!
      // Wait, IdeasService doesn't have getIdeaById. Let's just fetch all and find it for now to save time,
      // or better, I will implement it in IdeasService really quick.
      // Actually, IdeasService only has getIdeas (all). I'll fetch all and find.
      final ideas = await IdeasService.getIdeas(token: auth.token!);
      final idea = ideas.firstWhere((element) => element.id == widget.ideaId);

      if (mounted) {
        setState(() {
          _idea = idea;
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

  Future<void> _expandWithAI() async {
    if (_idea == null) return;
    setState(() => _isExpanding = true);
    try {
      final auth = context.read<AuthProvider>();
      final updatedIdea = await IdeasService.expandIdeaWithAI(token: auth.token!, ideaId: widget.ideaId);
      if (mounted) {
        setState(() {
          _idea = updatedIdea;
          _isExpanding = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExpanding = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error expanding idea: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _generateImage() async {
    if (_idea == null) return;
    setState(() => _isGeneratingImage = true);
    try {
      final auth = context.read<AuthProvider>();
      final updatedIdea = await IdeasService.generateIdeaImage(token: auth.token!, ideaId: widget.ideaId);
      if (mounted) {
        setState(() {
          _idea = updatedIdea;
          _isGeneratingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error generating image: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _uploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() => _isGeneratingImage = true); // Using this as a general loading state for image operations
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        
        // Ensure proper MIME type mapping (optional, but good for data URIs)
        final extension = image.name.split('.').last.toLowerCase();
        final mimeType = (extension == 'jpg' || extension == 'jpeg') ? 'image/jpeg' : 'image/png';
        
        final url = 'data:$mimeType;base64,$base64Image';

        final auth = context.read<AuthProvider>();
        final updatedIdea = await IdeasService.updateIdea(
          token: auth.token!, 
          ideaId: widget.ideaId, 
          imageUrl: url,
        );
        
        if (mounted) {
          setState(() {
            _idea = updatedIdea;
            _isGeneratingImage = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  Widget _buildSection(String title, IconData icon, List<String> items, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: const Color(0xFF13141C).withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(title.toUpperCase(), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: color, letterSpacing: 1.5)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 12),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 4)]),
                    ),
                    Expanded(child: Text(item, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.white70))),
                  ],
                ),
              )),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutExpo);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MeshGradientBg(
              colors: [
                const Color(0xFF0F172A),
                const Color(0xFF000000),
                cs.primary.withOpacity(0.15),
                AppColors.secondary.withOpacity(0.1),
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
                      CustomBackButton(onPressed: () => context.pop()),
                      const SizedBox(width: AppSpacing.md),
                      const Text('VAULT DATA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white54)),
                      const Spacer(),
                      if (_idea != null)
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10)],
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ProjectInsightsScreen(gameId: _idea!.id, gameName: _idea!.title)),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text('AI INSIGHTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : _error != null
                          ? Center(child: Text(_error!, style: TextStyle(color: cs.error)))
                          : _idea == null
                              ? const Center(child: Text('Data not found', style: TextStyle(color: Colors.white54)))
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (_idea!.imageUrl != null && _idea!.imageUrl!.isNotEmpty) ...[
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(24),
                                          child: _idea!.imageUrl!.startsWith('data:image')
                                            ? Image.memory(
                                                base64Decode(_idea!.imageUrl!.split(',').last),
                                                width: double.infinity,
                                                height: 220,
                                                fit: BoxFit.cover,
                                                errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                                              )
                                            : Image.network(
                                                _idea!.imageUrl!,
                                                width: double.infinity,
                                                height: 220,
                                                fit: BoxFit.cover,
                                                errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                                              ),
                                        ).animate().fadeIn().scaleXY(begin: 0.95),
                                        const SizedBox(height: AppSpacing.xxl),
                                      ],
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.02),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(_idea!.title.toUpperCase(), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
                                                ),
                                                IconButton(
                                                  onPressed: () {
                                                    showModalBottomSheet(
                                                      context: context,
                                                      backgroundColor: const Color(0xFF13141C),
                                                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                                                      builder: (context) => Padding(
                                                        padding: const EdgeInsets.all(24),
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Text('Cover Image', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                                            const SizedBox(height: 24),
                                                            ListTile(
                                                              leading: _isGeneratingImage ? const CircularProgressIndicator(color: AppColors.primary) : const Icon(Icons.auto_awesome, color: AppColors.primary),
                                                              title: const Text('Generate with AI', style: TextStyle(color: Colors.white)),
                                                              onTap: () {
                                                                Navigator.pop(context);
                                                                _generateImage();
                                                              },
                                                            ),
                                                            ListTile(
                                                              leading: const Icon(Icons.photo_library, color: AppColors.secondary),
                                                              title: const Text('Upload from Gallery', style: TextStyle(color: Colors.white)),
                                                              onTap: () {
                                                                Navigator.pop(context);
                                                                _uploadImage();
                                                              },
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(Icons.image, color: Colors.white54),
                                                  tooltip: 'Manage Cover Image',
                                                )
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            if (_idea!.tags.isNotEmpty) ...[
                                              Wrap(
                                                spacing: 8, runSpacing: 8,
                                                children: _idea!.tags.map((tag) => Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: cs.primary.withOpacity(0.15),
                                                    border: Border.all(color: cs.primary.withOpacity(0.3)),
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  child: Text(tag.toUpperCase(), style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
                                                )).toList(),
                                              ),
                                              const SizedBox(height: 24),
                                            ],
                                            Text(_idea!.description, style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.white70)),
                                          ],
                                        ),
                                      ).animate().fadeIn().slideY(begin: 0.1),
                                      const SizedBox(height: AppSpacing.xxxl),

                                      if (_idea!.expandedData == null) ...[
                                        const SizedBox(height: 40),
                                        Center(
                                          child: _isExpanding
                                              ? Column(
                                                  children: [
                                                    const SizedBox(height: 20),
                                                    SizedBox(
                                                      width: 80, height: 80,
                                                      child: Stack(
                                                        alignment: Alignment.center,
                                                        children: [
                                                          CircularProgressIndicator(color: cs.primary.withOpacity(0.2), strokeWidth: 8),
                                                          CircularProgressIndicator(color: cs.primary, strokeWidth: 4).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.2),
                                                        ]
                                                      )
                                                    ),
                                                    const SizedBox(height: 32),
                                                    Text('ANALYZING NEURAL PATHWAYS...', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900, letterSpacing: 2))
                                                      .animate(onPlay: (c) => c.repeat()).shimmer(duration: 1.seconds, color: Colors.white),
                                                    const SizedBox(height: 8),
                                                    const Text('Ollama is generating expansion data', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                                                  ],
                                                )
                                              : GestureDetector(
                                                  onTap: _expandWithAI,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(30),
                                                      gradient: LinearGradient(colors: [cs.primary.withOpacity(0.8), AppColors.secondary.withOpacity(0.8)]),
                                                      boxShadow: [
                                                        BoxShadow(color: cs.primary.withOpacity(0.4), blurRadius: 24, spreadRadius: -2),
                                                        BoxShadow(color: AppColors.secondary.withOpacity(0.4), blurRadius: 24, spreadRadius: -2),
                                                      ],
                                                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.psychology_alt_rounded, size: 32, color: Colors.white)
                                                            .animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds).scaleXY(end: 1.1),
                                                        const SizedBox(width: 16),
                                                        const Text('INITIALIZE AI EXPANSION', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
                                                      ],
                                                    ),
                                                  ),
                                                ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.02, duration: 2.seconds),
                                        ),
                                        const SizedBox(height: 40),
                                      ] else ...[
                                        Container(
                                          padding: const EdgeInsets.all(AppSpacing.lg),
                                          decoration: BoxDecoration(
                                            color: AppColors.secondary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(AppBorderRadius.large),
                                            border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.2), shape: BoxShape.circle),
                                                child: const Icon(Icons.radar_rounded, color: AppColors.secondary),
                                              ),
                                              const SizedBox(width: AppSpacing.md),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('DETECTED AUDIENCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 1.5)),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _idea!.expandedData!.targetAudience.toUpperCase(),
                                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.secondary, letterSpacing: 1),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ).animate().fadeIn().scale(),
                                        const SizedBox(height: AppSpacing.xl),
                                        
                                        _buildSection('Core Features', Icons.memory_rounded, _idea!.expandedData!.features, cs.primary),
                                        _buildSection('Monetization Strategy', Icons.monetization_on_rounded, _idea!.expandedData!.monetization, AppColors.success),
                                        _buildSection('Development Roadmap', Icons.alt_route_rounded, _idea!.expandedData!.roadmap, Colors.orangeAccent),
                                        _buildSection('Content & Marketing', Icons.campaign_rounded, _idea!.expandedData!.contentIdeas, Colors.pinkAccent),
                                      ]
                                    ],
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
