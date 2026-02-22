import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/projects_service.dart';
import '../../../core/services/templates_service.dart';
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

  Timer? _suggestDebounce;
  bool _loadingSuggestions = false;
  List<Map<String, dynamic>> _suggestions = const [];
  String? _selectedTemplateId;

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions(String q) async {
    final query = q.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadingSuggestions = false;
        _suggestions = const [];
        _selectedTemplateId = null;
      });
      return;
    }

    setState(() {
      _loadingSuggestions = true;
    });

    try {
      final res = await TemplatesService.listPublicTemplates(q: query);
      final raw = (res['success'] == true && res['data'] is List) ? (res['data'] as List) : const [];
      final items = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => ((e['_id'] ?? e['id'])?.toString() ?? '').trim().isNotEmpty)
          .take(6)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _suggestions = items;
        _loadingSuggestions = false;
        if (_selectedTemplateId != null) {
          final stillExists = _suggestions.any((t) => ((t['_id'] ?? t['id'])?.toString() ?? '') == _selectedTemplateId);
          if (!stillExists) _selectedTemplateId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSuggestions = false;
      });
    }
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
      final tpl = (_selectedTemplateId ?? '').trim();
      final res = tpl.isNotEmpty
          ? await ProjectsService.createFromAi(token: token, prompt: prompt, templateId: tpl)
          : await ProjectsService.createFromModulesAi(token: token, prompt: prompt);
      if (!mounted) return;

      final data = res['data'];
      final projectId = (data is Map) ? data['projectId']?.toString() : null;
      if (res['success'] == true && projectId != null && projectId.trim().isNotEmpty) {
        context.go(
          '/build-progress',
          extra: {
            'projectId': projectId,
            'prompt': prompt,
          },
        );
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
              onChanged: (v) {
                _suggestDebounce?.cancel();
                _suggestDebounce = Timer(const Duration(milliseconds: 420), () {
                  if (!mounted) return;
                  _loadSuggestions(v);
                });
              },
              decoration: const InputDecoration(
                hintText: 'Describe the game you want to generate...',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loadingSuggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Searching templates…',
                  style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            if (_suggestions.isNotEmpty) ...[
              Text('Suggested templates', style: AppTypography.subtitle2),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final t = _suggestions[i];
                    final id = (t['_id'] ?? t['id'])?.toString() ?? '';
                    final name = t['name']?.toString() ?? 'Template';
                    final category = t['category']?.toString() ?? '';
                    final selected = id.isNotEmpty && id == _selectedTemplateId;

                    return GestureDetector(
                      onTap: () {
                        if (id.trim().isEmpty) return;
                        setState(() {
                          _selectedTemplateId = selected ? null : id;
                        });
                      },
                      child: Container(
                        width: 220,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: selected ? cs.primary.withOpacity(0.12) : cs.surface,
                          borderRadius: BorderRadius.circular(AppBorderRadius.large),
                          border: Border.all(
                            color: selected ? cs.primary.withOpacity(0.55) : cs.outlineVariant.withOpacity(0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body2.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ] else
              const SizedBox(height: AppSpacing.md),
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
