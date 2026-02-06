import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/themes/app_theme.dart';
import '../../presentation/widgets/widgets.dart';

class AIConfigurationScreen extends StatefulWidget {
  const AIConfigurationScreen({super.key});

  @override
  State<AIConfigurationScreen> createState() => _AIConfigurationScreenState();
}

class _AIConfigurationScreenState extends State<AIConfigurationScreen> {
  String _selectedModel = 'GPT-4';
  double _creativityLevel = 0.7;
  bool _includeAIAssets = true;
  bool _optimizeForMobile = true;
  bool _enableMultiplayer = false;
  bool _useAdvancedPhysics = false;

  final List<String> _aiModels = [
    'GPT-4',
    'GPT-3.5',
    'Claude-3',
    'Gemini Pro',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          'AI Settings',
          style: AppTypography.subtitle1.copyWith(color: cs.onSurface),
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
          // Progress indicator (3/4)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Center(
              child: Text(
                '3/4',
                style: AppTypography.caption.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundGradient
              : AppTheme.backgroundGradientLight,
        ),
        child: Column(
        children: [
          // Progress bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary,
                  cs.primary.withOpacity(0.3),
                ],
              ),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.75, // 3/4 = 0.75
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
              ),
            ),
          ),
          
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: AppSpacing.paddingLarge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  
                  // AI Model Selection
                  Text(
                    'AI Model',
                    style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
                  ),
                  
                  const SizedBox(height: AppSpacing.sm),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(AppBorderRadius.large),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      children: _aiModels.map((model) {
                        final isSelected = model == _selectedModel;
                        return _buildModelOption(model, isSelected);
                      }).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Creativity Level
                  Text(
                    'Creativity Level',
                    style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
                  ),
                  
                  const SizedBox(height: AppSpacing.sm),
                  
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(AppBorderRadius.large),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Creativity',
                              style: AppTypography.body2.copyWith(color: cs.onSurface),
                            ),
                            Text(
                              '${(_creativityLevel * 100).toInt()}%',
                              style: AppTypography.body2.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: AppSpacing.md),
                        
                        Slider(
                          value: _creativityLevel,
                          onChanged: (value) {
                            setState(() {
                              _creativityLevel = value;
                            });
                          },
                          min: 0.1,
                          max: 1.0,
                          activeColor: cs.primary,
                          inactiveColor: cs.outlineVariant,
                        ),
                        
                        const SizedBox(height: AppSpacing.md),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Conservative',
                              style: AppTypography.caption.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'Creative',
                              style: AppTypography.caption.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Features
                  Text(
                    'Features',
                    style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
                  ),
                  
                  const SizedBox(height: AppSpacing.sm),
                  
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(AppBorderRadius.large),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        _buildFeatureToggle(
                          'Include AI-generated assets',
                          'Generate custom sprites, sounds, and textures',
                          _includeAIAssets,
                          (value) {
                            setState(() {
                              _includeAIAssets = value;
                            });
                          },
                          Icons.image,
                        ),
                        
                        Divider(color: cs.outlineVariant),
                        
                        _buildFeatureToggle(
                          'Optimize for mobile',
                          'Ensure smooth performance on mobile devices',
                          _optimizeForMobile,
                          (value) {
                            setState(() {
                              _optimizeForMobile = value;
                            });
                          },
                          Icons.phone_android,
                        ),
                        
                        Divider(color: cs.outlineVariant),
                        
                        _buildFeatureToggle(
                          'Enable multiplayer',
                          'Add online multiplayer functionality',
                          _enableMultiplayer,
                          (value) {
                            setState(() {
                              _enableMultiplayer = value;
                            });
                          },
                          Icons.people,
                        ),
                        
                        Divider(color: cs.outlineVariant),
                        
                        _buildFeatureToggle(
                          'Advanced physics',
                          'Realistic physics simulation',
                          _useAdvancedPhysics,
                          (value) {
                            setState(() {
                              _useAdvancedPhysics = value;
                            });
                          },
                          Icons.science,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xxxl),
                  
                  // AI Capabilities Info
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppBorderRadius.large),
                      border: Border.all(color: cs.primary.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: cs.primary,
                            ),
                            
                            const SizedBox(width: AppSpacing.md),
                            
                            Text(
                              'AI Capabilities',
                              style: AppTypography.subtitle2.copyWith(
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: AppSpacing.md),
                        
                        ...[
                          '• Generate game mechanics and rules',
                          '• Create level designs and layouts',
                          '• Design characters and story elements',
                          '• Generate UI/UX components',
                          '• Create sound effects and music',
                        ].map((capability) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text(
                            capability,
                            style: AppTypography.caption.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          ),
          
          // Bottom button
          Container(
            padding: AppSpacing.paddingLarge,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(color: cs.outlineVariant),
              ),
            ),
            child: CustomButton(
              text: 'Generate Game',
              onPressed: _generateGame,
              type: ButtonType.primary,
              size: ButtonSize.large,
              isFullWidth: true,
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildModelOption(String model, bool isSelected) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedModel = model;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
            ),
            
            const SizedBox(width: AppSpacing.lg),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model,
                    style: AppTypography.body2.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xs),
                  
                  Text(
                    _getModelDescription(model),
                    style: AppTypography.caption.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: AppBorderRadius.allSmall,
                ),
                child: Text(
                  'Recommended',
                  style: AppTypography.caption.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureToggle(
    String title,
    String description,
    bool value,
    ValueChanged<bool> onChanged,
    IconData icon,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(
            icon,
            color: cs.primary,
            size: 20,
          ),
          
          const SizedBox(width: AppSpacing.lg),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body2.copyWith(color: cs.onSurface),
                ),
                
                const SizedBox(height: AppSpacing.xs),
                
                Text(
                  description,
                  style: AppTypography.caption.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: cs.primary,
          ),
        ],
      ),
    );
  }

  String _getModelDescription(String model) {
    switch (model) {
      case 'GPT-4':
        return 'Most advanced, best for complex games';
      case 'GPT-3.5':
        return 'Fast and efficient, good for simple games';
      case 'Claude-3':
        return 'Great for story-driven games';
      case 'Gemini Pro':
        return 'Excellent for visual and creative elements';
      default:
        return 'AI model for game generation';
    }
  }

  void _generateGame() {
    // Navigate to generation progress screen
    context.go('/generation-progress');
  }
}
