import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../widgets/widgets.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundGradient
              : AppTheme.backgroundGradientLight,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Custom App Bar with back button
              _buildCustomAppBar(),
              
              const SizedBox(height: AppSpacing.lg),
              
              // Main content
              Expanded(
                child: Padding(
                  padding: AppSpacing.paddingHorizontalLarge,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Permission icon
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.1),
                            boxShadow: AppShadows.boxShadowPrimaryGlow,
                          ),
                          child: const Icon(
                            Icons.security,
                            size: 60,
                            color: AppColors.primary,
                          ),
                        ),
                        
                        const SizedBox(height: AppSpacing.xxxl),
                        
                        // Title
                        Text(
                          'Enable Full Experience',
                          style: AppTypography.h2,
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: AppSpacing.lg),
                        
                        // Subtitle
                        Text(
                          'GameForge AI needs some permissions to provide you with the best game creation experience.',
                          style: AppTypography.body1.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: AppSpacing.xxxl),
                        
                        // Permissions list
                        _buildPermissionItem(
                          icon: Icons.camera_alt,
                          title: 'Camera Access',
                          description: 'To capture images for custom game assets and textures',
                        ),
                        
                        const SizedBox(height: AppSpacing.lg),
                        
                        _buildPermissionItem(
                          icon: Icons.storage,
                          title: 'Storage Access',
                          description: 'To save your projects and generated game files',
                        ),
                        
                        const SizedBox(height: AppSpacing.lg),
                        
                        _buildPermissionItem(
                          icon: Icons.mic,
                          title: 'Microphone Access',
                          description: 'For voice commands and audio recording in games',
                        ),
                        
                        const SizedBox(height: AppSpacing.xxxl),
                        
                        // Buttons
                        Row(
                          children: [
                            // Not Now button
                            Expanded(
                              child: CustomButton(
                                text: 'Not Now',
                                onPressed: () {
                                  context.go('/signin');
                                },
                                type: ButtonType.ghost,
                                isFullWidth: true,
                              ),
                            ),
                            
                            const SizedBox(width: AppSpacing.lg),
                            
                            // Grant Permissions button
                            Expanded(
                              child: CustomButton(
                                text: 'Grant Permissions',
                                onPressed: () => _requestPermissions(context),
                                type: ButtonType.primary,
                                isFullWidth: true,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      height: kToolbarHeight + AppSpacing.sm,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button with WOW design
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              border: Border.all(
                color: AppColors.border.withOpacity(0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/welcome');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Icon(
                    Icons.arrow_back,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          
          // Title with gradient - Centered
          Expanded(
            child: Center(
              child: ShaderMask(
                shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                child: Text(
                  'Permissions',
                  style: AppTypography.h2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          
          // Progress indicator (3/3) with WOW design
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              border: Border.all(
                color: AppColors.border.withOpacity(0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          
          const SizedBox(width: AppSpacing.lg),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.subtitle2,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermissions(BuildContext context) async {
    try {
      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      
      // Request storage permission
      final storageStatus = await Permission.storage.request();
      
      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      
      // Show dialog with results
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permissions Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPermissionStatus('Camera', cameraStatus),
              _buildPermissionStatus('Storage', storageStatus),
              _buildPermissionStatus('Microphone', micStatus),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                }
                context.go('/signin');
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error requesting permissions: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildPermissionStatus(String permission, PermissionStatus status) {
    Color statusColor;
    String statusText;
    
    switch (status) {
      case PermissionStatus.granted:
        statusColor = AppColors.success;
        statusText = 'Granted';
        break;
      case PermissionStatus.denied:
        statusColor = AppColors.warning;
        statusText = 'Denied';
        break;
      case PermissionStatus.permanentlyDenied:
        statusColor = AppColors.error;
        statusText = 'Permanently Denied';
        break;
      case PermissionStatus.limited:
        statusColor = AppColors.warning;
        statusText = 'Limited';
        break;
      case PermissionStatus.provisional:
        statusColor = AppColors.warning;
        statusText = 'Provisional';
        break;
      case PermissionStatus.restricted:
        statusColor = AppColors.error;
        statusText = 'Restricted';
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusText = 'Unknown';
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            '$permission: ',
            style: AppTypography.body2,
          ),
          Text(
            statusText,
            style: AppTypography.body2.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
