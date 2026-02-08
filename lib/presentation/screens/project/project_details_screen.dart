import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/widgets.dart';
import 'template_selection_screen.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/projects_service.dart';

class ProjectDetailsScreen extends StatefulWidget {
  const ProjectDetailsScreen({super.key});

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<String> _tags = [];
  bool _showAdvancedSettings = false;
  GameTemplate? _selectedTemplate;
  bool _initializedFromRoute = false;

  bool _creating = false;
  String? _error;
  int _buildStep = 0;
  String? _downloadUrl;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromRoute) return;
    _initializedFromRoute = true;

    // Récupérer le template sélectionné depuis les paramètres de navigation
    final extra = GoRouterState.of(context).extra;
    _selectedTemplate = extra as GameTemplate?;
    if (_selectedTemplate != null) {
      _nameController.text = _selectedTemplate!.name;
      _descriptionController.text = _selectedTemplate!.description;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          'Project Details',
          style: AppTypography.subtitle1,
        ),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
          icon: Icon(
            Icons.arrow_back,
            color: cs.onSurface,
          ),
        ),
        actions: [
          // Progress indicator (2/4)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Center(
              child: Text(
                '2/4',
                style: AppTypography.caption.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLarge,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_creating || _downloadUrl != null) ...[
                _buildBuildSection(cs),
                const SizedBox(height: AppSpacing.lg),
              ],
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
              // Template info card
              if (_selectedTemplate != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    border: Border.all(
                      color: cs.primary.withOpacity(0.28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: cs.primary,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Template Selected',
                            style: AppTypography.body2.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _selectedTemplate!.name,
                        style: AppTypography.h3.copyWith(
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _selectedTemplate!.description,
                        style: AppTypography.body2.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              
              // Form fields
              const SizedBox(height: AppSpacing.xl),
              
              // Project name
              Text(
                'Project Name',
                style: AppTypography.subtitle2,
              ),
              
              const SizedBox(height: AppSpacing.sm),
              
              CustomTextField(
                hint: 'Enter your project name',
                controller: _nameController,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a project name';
                  }
                  if (value.length < 2) {
                    return 'Project name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: AppSpacing.xl),
              
              // Description
              Text(
                'Description',
                style: AppTypography.subtitle2,
              ),
              
              const SizedBox(height: AppSpacing.sm),
              
              CustomTextField(
                hint: 'Describe your game concept',
                controller: _descriptionController,
                maxLines: 4,
                textInputAction: TextInputAction.next,
                maxLength: 500,
                showCharacterCount: true,
              ),
              
              const SizedBox(height: AppSpacing.xl),
              
              // Tags
              Text(
                'Tags',
                style: AppTypography.subtitle2,
              ),
              
              const SizedBox(height: AppSpacing.sm),
              
              ChipInput(
                chips: _tags,
                onChanged: (chips) {
                  setState(() {
                    _tags.clear();
                    _tags.addAll(chips);
                  });
                },
                hint: 'Add tags...',
                prefixIcon: Icons.tag,
              ),
              
              const SizedBox(height: AppSpacing.xxxl),
              
              // Advanced Settings
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showAdvancedSettings = !_showAdvancedSettings;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings,
                        color: cs.primary,
                      ),
                      
                      const SizedBox(width: AppSpacing.lg),
                      
                      Expanded(
                        child: Text(
                          'Advanced Settings',
                          style: AppTypography.subtitle2,
                        ),
                      ),
                      
                      Icon(
                        _showAdvancedSettings 
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Advanced settings content
              if (_showAdvancedSettings) ...[
                const SizedBox(height: AppSpacing.lg),
                
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Target platforms
                      Text(
                        'Target Platforms',
                        style: AppTypography.subtitle2,
                      ),
                      
                      const SizedBox(height: AppSpacing.md),
                      
                      _buildPlatformCheckbox('iOS', Icons.phone_iphone),
                      _buildPlatformCheckbox('Android', Icons.phone_android),
                      _buildPlatformCheckbox('Web', Icons.language),
                      _buildPlatformCheckbox('Desktop', Icons.desktop_windows),
                      
                      const SizedBox(height: AppSpacing.xl),
                      
                      // Game engine preference
                      Text(
                        'Game Engine',
                        style: AppTypography.subtitle2,
                      ),
                      
                      const SizedBox(height: AppSpacing.sm),
                      
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.code,
                              color: cs.primary,
                            ),
                            
                            const SizedBox(width: AppSpacing.lg),
                            
                            Expanded(
                              child: Text(
                                'Unity (Recommended)',
                                style: AppTypography.body2,
                              ),
                            ),
                            
                            Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: AppSpacing.xxl),
              
              // Create project button
              CustomButton(
                text: _creating ? 'Creating…' : (_downloadUrl != null ? 'Create Another Project' : 'Create Project'),
                onPressed: _creating
                    ? null
                    : () async {
                        setState(() {
                          _error = null;
                          _downloadUrl = null;
                          _buildStep = 0;
                        });

                        if (_selectedTemplate == null) {
                          setState(() {
                            _error = 'Please select a template first.';
                          });
                          return;
                        }

                        if (!_formKey.currentState!.validate()) return;

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
                          _buildStep = 1;
                        });

                        try {
                          final created = await ProjectsService.createFromTemplate(
                            token: token,
                            templateId: _selectedTemplate!.id,
                            name: _nameController.text,
                            description: _descriptionController.text,
                          );
                          final data = created['data'];
                          final projectId = (data is Map)
                              ? (data['_id']?.toString() ?? data['id']?.toString())
                              : null;
                          if (projectId == null || projectId.isEmpty) {
                            throw Exception('Missing project id');
                          }

                          while (true) {
                            final p = await ProjectsService.getProject(token: token, projectId: projectId);
                            final pd = (p['data'] is Map) ? Map<String, dynamic>.from(p['data']) : <String, dynamic>{};
                            final status = pd['status']?.toString();
                            if (mounted) {
                              setState(() {
                                _buildStep = status == 'queued' ? 1 : 2;
                              });
                            }
                            if (status == 'ready') break;
                            if (status == 'failed') {
                              throw Exception(pd['error']?.toString() ?? 'Project build failed');
                            }
                            await Future<void>.delayed(const Duration(milliseconds: 650));
                          }

                          if (mounted) {
                            setState(() {
                              _buildStep = 3;
                            });
                          }

                          final urlRes = await ProjectsService.getProjectDownloadUrl(token: token, projectId: projectId);
                          final url = (urlRes['data'] is Map) ? urlRes['data']['url']?.toString() : null;
                          if (url == null || url.isEmpty) throw Exception('Missing download url');

                          if (!mounted) return;
                          setState(() {
                            _downloadUrl = url;
                          });
                        } catch (e) {
                          setState(() {
                            _error = e.toString();
                          });
                        } finally {
                          if (mounted) {
                            setState(() {
                              _creating = false;
                            });
                          }
                        }
                      },
                isFullWidth: true,
              ),
              
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformCheckbox(String platform, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: cs.onSurfaceVariant, size: 20),
          const SizedBox(width: AppSpacing.md),
          Text(platform, style: AppTypography.body2),
          const Spacer(),
          Checkbox(
            value: true,
            onChanged: (value) {},
            activeColor: cs.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildBuildSection(ColorScheme cs) {
    final title = _downloadUrl != null ? 'Project ready' : 'Analysis & build';

    Widget stepDot({required bool active, required bool done}) {
      final bg = done
          ? AppColors.success
          : (active ? cs.primary : cs.outlineVariant.withOpacity(0.6));
      final fg = done || active ? cs.onPrimary : cs.onSurfaceVariant;
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(done ? Icons.check : Icons.circle, size: done ? 16 : 10, color: fg),
        ),
      );
    }

    Widget stepLine(bool activeOrDone) {
      return Expanded(
        child: Container(
          height: 2,
          color: activeOrDone ? cs.primary : cs.outlineVariant.withOpacity(0.5),
        ),
      );
    }

    final s1Done = _buildStep >= 1;
    final s2Done = _buildStep >= 2;
    final s3Done = _buildStep >= 3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.subtitle1.copyWith(color: cs.onSurface)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              stepDot(active: _buildStep == 1, done: s1Done && _buildStep > 1),
              stepLine(s1Done),
              stepDot(active: _buildStep == 2, done: s2Done && _buildStep > 2),
              stepLine(s2Done),
              stepDot(active: _buildStep == 3, done: s3Done),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Queued', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
              Text('Building', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
              Text('Ready', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          if (_downloadUrl != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.4),
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
              ),
              child: Text(
                _downloadUrl!,
                style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final url = _downloadUrl;
                      if (url == null || url.trim().isEmpty) return;
                      await Clipboard.setData(ClipboardData(text: url));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy link'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final url = _downloadUrl;
                      if (url == null || url.trim().isEmpty) return;
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              _buildStep <= 1
                  ? 'Preparing your project…'
                  : _buildStep == 2
                      ? 'Building Unity project…'
                      : 'Finalizing…',
              style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
