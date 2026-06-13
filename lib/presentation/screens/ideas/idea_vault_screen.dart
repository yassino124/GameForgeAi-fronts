import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/ideas_service.dart';
import '../../../data/models/idea_model.dart';
import '../../widgets/mesh_gradient_bg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class IdeaVaultScreen extends StatefulWidget {
  const IdeaVaultScreen({super.key});

  @override
  State<IdeaVaultScreen> createState() => _IdeaVaultScreenState();
}

class _IdeaVaultScreenState extends State<IdeaVaultScreen> {
  bool _isLoading = true;
  List<IdeaModel> _ideas = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIdeas();
  }

  Future<void> _loadIdeas() async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final auth = context.read<AuthProvider>();
      if (auth.token == null) throw Exception('Please log in first.');
      
      final ideas = await IdeasService.getIdeas(token: auth.token!);
      if (mounted) {
        setState(() {
          _ideas = ideas;
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

  void _showAddIdeaDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final tagsController = TextEditingController();
    bool isSaving = false;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: 400.ms,
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: StatefulBuilder(
              builder: (context, setStateDialog) {
                return AlertDialog(
                  backgroundColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 20),
                  content: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2A).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, spreadRadius: -5),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text('Add New Idea', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            _buildPremiumTextField(titleController, 'Idea Title', 'e.g. AI Fitness Coach', Icons.title_rounded),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(descController, 'Description', 'What does it do?', Icons.description_outlined, maxLines: 3),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(tagsController, 'Tags', 'ai, health, app', Icons.tag_rounded),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: isSaving ? null : () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                      onPressed: isSaving ? null : () async {
                                        final title = titleController.text.trim();
                                        final desc = descController.text.trim();
                                        if (title.isEmpty || desc.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                            content: Text('Title and Description are required!'),
                                            backgroundColor: Colors.redAccent,
                                          ));
                                          return;
                                        }
                                        setStateDialog(() => isSaving = true);
                                        try {
                                          final auth = context.read<AuthProvider>();
                                          await IdeasService.createIdea(
                                            token: auth.token!,
                                            title: titleController.text.trim(),
                                            description: descController.text.trim(),
                                            tags: tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                                          );
                                          if (mounted) {
                                            Navigator.pop(context);
                                            _loadIdeas();
                                          }
                                        } catch (e) {
                                          setStateDialog(() => isSaving = false);
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: isSaving 
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                          : const Text('Save Idea', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                );
              }
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumTextField(TextEditingController controller, String label, String hint, IconData icon, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w500),
          floatingLabelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          prefixIcon: maxLines == 1 
              ? Icon(icon, color: AppColors.primary.withOpacity(0.8)) 
              : Padding(padding: const EdgeInsets.only(bottom: 48), child: Icon(icon, color: AppColors.primary.withOpacity(0.8))),
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16), 
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16), 
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16), 
            borderSide: const BorderSide(color: Colors.redAccent, width: 1),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            context.go('/dashboard?tab=home');
          },
        ),
        title: const Text('Idea Vault 💡', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: AppColors.secondary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showAddIdeaDialog,
          icon: const Icon(Icons.add_circle_outline, size: 24),
          label: const Text('New Idea', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
        ),
      ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.5),
      body: Stack(
        children: [
          Positioned.fill(
            child: MeshGradientBg(
              colors: [
                const Color(0xFF1E0F2A), // Deep purple
                AppColors.primary.withOpacity(0.3),
                AppColors.secondary.withOpacity(0.4),
                const Color(0xFF000000),
              ],
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: cs.error)))
              : _ideas.isEmpty
                  ? Center(
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
                            child: const Icon(Icons.lightbulb_outline, size: 80, color: Colors.white54),
                          ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.05, duration: 2.seconds),
                          const SizedBox(height: 24),
                          Text('Your vault is empty!', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)).animate().fadeIn(delay: 300.ms),
                          const SizedBox(height: 8),
                          Text('Add an idea and let AI expand it for you.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white60)).animate().fadeIn(delay: 500.ms),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _ideas.length,
                      itemBuilder: (context, index) {
                        final idea = _ideas[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: InkWell(
                                  onTap: () async {
                                    await context.push('/ideas/${idea.id}', extra: idea);
                                    _loadIdeas(); // Refresh when coming back
                                  },
                                  child: Container(
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
                                      border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        if (idea.imageUrl != null && idea.imageUrl!.isNotEmpty)
                                          ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                                            child: idea.imageUrl!.startsWith('data:image')
                                              ? Image.memory(
                                                  base64Decode(idea.imageUrl!.split(',').last),
                                                  height: 160,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                                                )
                                              : Image.network(
                                                  idea.imageUrl!,
                                                  height: 160,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                                                ),
                                          )
                                        else
                                          Container(
                                            height: 60,
                                            decoration: BoxDecoration(
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                                              gradient: LinearGradient(
                                                colors: [AppColors.primary.withOpacity(0.2), AppColors.secondary.withOpacity(0.1)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(idea.title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white, letterSpacing: 1.2)),
                                                    const SizedBox(height: 12),
                                                    Text(idea.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
                                                    const SizedBox(height: 20),
                                                    Wrap(
                                                      spacing: 10,
                                                      runSpacing: 10,
                                                      children: idea.tags.map((tag) => Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.3), AppColors.secondary.withOpacity(0.2)]),
                                                          borderRadius: BorderRadius.circular(20),
                                                          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                                                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 8)],
                                                        ),
                                                        child: Text('#${tag.toUpperCase()}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                                                      )).toList(),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  if (idea.expandedData != null)
                                                    Container(
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.secondary.withOpacity(0.15),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(color: AppColors.secondary.withOpacity(0.5)),
                                                        boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.2), blurRadius: 12)],
                                                      ),
                                                      child: const Icon(Icons.auto_awesome, color: AppColors.secondary, size: 28),
                                                    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds, color: Colors.white)
                                                  else
                                                    Container(
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.05),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 20),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ),
                          ),
                        ).animate().fadeIn(delay: (100 * index).ms).slideY(begin: 0.2);
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
