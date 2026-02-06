import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../presentation/widgets/widgets.dart';
import 'template_selection_screen.dart';

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
              
              // Next button
              CustomButton(
                text: 'Next',
                onPressed: () => context.go('/ai-configuration'),
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
}
