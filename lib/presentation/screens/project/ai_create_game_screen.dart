import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/projects_service.dart';
import '../../widgets/widgets.dart';

class AiCreateGameScreen extends StatefulWidget {
  const AiCreateGameScreen({super.key});

  @override
  State<AiCreateGameScreen> createState() => _AiCreateGameScreenState();
}

class _AiCreateGameScreenState extends State<AiCreateGameScreen> {
  final _promptController = TextEditingController();
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_creating) return;
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _error = 'Please enter a prompt';
      });
      return;
    }

    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Session expired. Please sign in again.';
      });
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final res = await ProjectsService.createFromAi(token: token, prompt: prompt);
      if (!mounted) return;

      final data = res['data'];
      final projectId = (data is Map) ? data['projectId']?.toString() : null;
      if (res['success'] == true && projectId != null && projectId.trim().isNotEmpty) {
        context.go('/project-detail', extra: {'projectId': projectId});
        return;
      }

      setState(() {
        _error = res['message']?.toString() ?? 'Failed to create project';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text('Create with AI', style: AppTypography.subtitle1),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
        ),
        actions: [
          IconButton(
            tooltip: 'Coach Guide',
            onPressed: () {
              context.push('/ai-coach');
            },
            icon: Icon(Icons.mic_rounded, color: cs.onSurface),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  border: Border.all(color: AppColors.error.withOpacity(0.35)),
                ),
                child: Text(
                  _error!,
                  style: AppTypography.body2.copyWith(color: cs.onSurface),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text('Prompt', style: AppTypography.subtitle2),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _promptController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Describe the game you want to generate...',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            CustomButton(
              text: _creating ? 'Creating…' : 'Generate Game',
              onPressed: _creating ? null : _create,
              isFullWidth: true,
              type: ButtonType.primary,
              icon: const Icon(Icons.auto_awesome),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This will create a project and start the build. When ready, you can play it in WebGL.',
              style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
