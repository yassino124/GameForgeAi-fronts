import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/themes/app_theme.dart';
import '../../presentation/widgets/widgets.dart';

class BuildConfigurationScreen extends StatefulWidget {
  const BuildConfigurationScreen({super.key});

  @override
  State<BuildConfigurationScreen> createState() => _BuildConfigurationScreenState();
}

class _BuildConfigurationScreenState extends State<BuildConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _versionController = TextEditingController(text: '1.0.0');
  final _bundleIdController = TextEditingController(text: 'com.gameforge.mygame');
  
  final List<Platform> _platforms = [
    Platform(
      name: 'iOS',
      icon: Icons.phone_iphone,
      isSelected: true,
      requirements: 'iOS 12.0 or later',
    ),
    Platform(
      name: 'Android',
      icon: Icons.phone_android,
      isSelected: true,
      requirements: 'Android 5.0 or later',
    ),
    Platform(
      name: 'Web',
      icon: Icons.language,
      isSelected: false,
      requirements: 'Modern web browser',
    ),
    Platform(
      name: 'Windows',
      icon: Icons.desktop_windows,
      isSelected: false,
      requirements: 'Windows 10 or later',
    ),
    Platform(
      name: 'macOS',
      icon: Icons.laptop_mac,
      isSelected: false,
      requirements: 'macOS 10.14 or later',
    ),
    Platform(
      name: 'Linux',
      icon: Icons.computer,
      isSelected: false,
      requirements: 'Ubuntu 18.04 or later',
    ),
  ];

  @override
  void dispose() {
    _versionController.dispose();
    _bundleIdController.dispose();
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
          'Build Your Game',
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
      ),
      
      body: Column(
        children: [
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: AppSpacing.paddingLarge,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    
                    // Platform Selection
                    Text(
                      'Select Platforms',
                      style: AppTypography.subtitle2,
                    ),
                    
                    const SizedBox(height: AppSpacing.sm),
                    
                    Text(
                      'Choose where you want to deploy your game',
                      style: AppTypography.caption.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.lg),
                    
                    // Platform grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: AppSpacing.lg,
                        mainAxisSpacing: AppSpacing.lg,
                      ),
                      itemCount: _platforms.length,
                      itemBuilder: (context, index) {
                        return _buildPlatformCard(_platforms[index], index);
                      },
                    ),
                    
                    const SizedBox(height: AppSpacing.xxxl),
                    
                    // Build Settings
                    Text(
                      'Build Settings',
                      style: AppTypography.subtitle2,
                    ),
                    
                    const SizedBox(height: AppSpacing.lg),
                    
                    // Version number
                    CustomTextField(
                      label: 'Version Number',
                      hint: 'e.g., 1.0.0',
                      controller: _versionController,
                      prefixIcon: Icons.tag,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a version number';
                        }
                        if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value)) {
                          return 'Please use format: major.minor.patch';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: AppSpacing.lg),
                    
                    // Bundle ID
                    CustomTextField(
                      label: 'Bundle ID',
                      hint: 'e.g., com.company.appname',
                      controller: _bundleIdController,
                      prefixIcon: Icons.apps,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a bundle ID';
                        }
                        if (!RegExp(r'^[a-z]+\.[a-z]+\.[a-z]+$').hasMatch(value)) {
                          return 'Please use format: com.company.appname';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: AppSpacing.xl),
                    
                    // Icon and Splash Screen
                    Text(
                      'Assets',
                      style: AppTypography.subtitle2,
                    ),
                    
                    const SizedBox(height: AppSpacing.lg),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildAssetUpload(
                            'App Icon',
                            'Upload app icon',
                            Icons.image,
                          ),
                        ),
                        
                        const SizedBox(width: AppSpacing.lg),
                        
                        Expanded(
                          child: _buildAssetUpload(
                            'Splash Screen',
                            'Upload splash screen',
                            Icons.wallpaper,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: AppSpacing.xxxl),
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom button
          Container(
            padding: AppSpacing.paddingLarge,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
              ),
            ),
            child: CustomButton(
              text: 'Start Build',
              onPressed: _startBuild,
              type: ButtonType.primary,
              size: ButtonSize.large,
              isFullWidth: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformCard(Platform platform, int index) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        setState(() {
          _platforms[index].isSelected = !_platforms[index].isSelected;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          border: Border.all(
            color: platform.isSelected ? cs.primary : cs.outlineVariant.withOpacity(0.6),
            width: platform.isSelected ? 2 : 1,
          ),
          boxShadow: AppShadows.boxShadowSmall,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Platform icon
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: platform.isSelected 
                    ? cs.primary.withOpacity(0.12)
                    : cs.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                platform.icon,
                size: 28,
                color: platform.isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
            
            const SizedBox(height: AppSpacing.sm),
            
            // Platform name
            Text(
              platform.name,
              style: AppTypography.subtitle2.copyWith(
                color: platform.isSelected ? cs.primary : cs.onSurface,
                fontWeight: platform.isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            
            const SizedBox(height: AppSpacing.xs),
            
            // Requirements
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(
                  platform.requirements,
                  style: AppTypography.caption.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            
            // Selection indicator
            if (platform.isSelected)
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: AppBorderRadius.allSmall,
                ),
                child: Text(
                  'Selected',
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

  Widget _buildAssetUpload(String title, String hint, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: cs.primary,
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          Text(
            title,
            style: AppTypography.subtitle2,
          ),
          
          const SizedBox(height: AppSpacing.sm),
          
          Text(
            hint,
            style: AppTypography.caption.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          CustomButton(
            text: 'Upload',
            onPressed: () {
              // TODO: Implement file upload
            },
            type: ButtonType.secondary,
            size: ButtonSize.small,
          ),
        ],
      ),
    );
  }

  void _startBuild() {
    if (_formKey.currentState!.validate()) {
      final selectedPlatforms = _platforms.where((p) => p.isSelected).toList();
      
      if (selectedPlatforms.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one platform'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      
      context.go('/build-progress');
    }
  }
}

class Platform {
  final String name;
  final IconData icon;
  final String requirements;
  bool isSelected;

  Platform({
    required this.name,
    required this.icon,
    required this.requirements,
    this.isSelected = false,
  });
}
