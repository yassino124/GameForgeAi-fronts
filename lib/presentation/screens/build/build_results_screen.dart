import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/themes/app_theme.dart';
import '../../presentation/widgets/widgets.dart';

class BuildResultsScreen extends StatelessWidget {
  const BuildResultsScreen({super.key});

  final List<BuildResult> _buildResults = const [
    BuildResult(
      platform: 'iOS',
      status: BuildStatus.completed,
      fileSize: '45.2 MB',
      downloadUrl: 'https://gameforge.ai/download/ios/abc123',
      qrCode: 'https://gameforge.ai/download/ios/abc123',
      buildTime: '3 min 15 sec',
      icon: Icons.phone_iphone,
    ),
    BuildResult(
      platform: 'Android',
      status: BuildStatus.completed,
      fileSize: '38.7 MB',
      downloadUrl: 'https://gameforge.ai/download/android/def456',
      qrCode: 'https://gameforge.ai/download/android/def456',
      buildTime: '2 min 45 sec',
      icon: Icons.phone_android,
    ),
    BuildResult(
      platform: 'Web',
      status: BuildStatus.completed,
      fileSize: '12.3 MB',
      downloadUrl: 'https://gameforge.ai/play/ghi789',
      qrCode: 'https://gameforge.ai/play/ghi789',
      buildTime: '1 min 20 sec',
      icon: Icons.language,
    ),
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
          'Build Results',
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
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundGradient
              : AppTheme.backgroundGradientLight,
        ),
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const SizedBox(height: AppSpacing.xl),
            
            // Success animation
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withOpacity(0.1),
                  boxShadow: AppShadows.custom(color: AppColors.success),
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 60,
                  color: AppColors.success,
                ),
              ),
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // Success message
            Text(
              'Build Completed Successfully!',
              style: AppTypography.h2.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            Text(
              'Your game is ready for deployment across all selected platforms.',
              style: AppTypography.body1.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppSpacing.xxxl),
            
            // Build statistics
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Build Statistics',
                    style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Total Build Time',
                          '7 min 20 sec',
                          Icons.timer,
                          AppColors.primary,
                        ),
                      ),
                      
                      const SizedBox(width: AppSpacing.lg),
                      
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Total Size',
                          '96.2 MB',
                          Icons.storage,
                          AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Platforms',
                          '${_buildResults.length}',
                          Icons.devices,
                          AppColors.success,
                        ),
                      ),
                      
                      const SizedBox(width: AppSpacing.lg),
                      
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Success Rate',
                          '100%',
                          Icons.trending_up,
                          AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxxl),
            
            // Platform results
            Text(
              'Platform Downloads',
              style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            ..._buildResults.map((result) => _buildPlatformResult(context, result)),
            
            const SizedBox(height: AppSpacing.xxxl),
            
            // Share section
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.share,
                        color: cs.primary,
                      ),
                      
                      const SizedBox(width: AppSpacing.md),
                      
                      Text(
                        'Share Your Game',
                        style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  Text(
                    'Share your game with friends and players to get feedback and build your community.',
                    style: AppTypography.caption.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Share Link',
                          onPressed: () {
                            _shareGameLink(context);
                          },
                          type: ButtonType.secondary,
                          icon: const Icon(Icons.link),
                        ),
                      ),
                      
                      const SizedBox(width: AppSpacing.lg),
                      
                      Expanded(
                        child: CustomButton(
                          text: 'Copy QR Code',
                          onPressed: () {
                            _copyQRCode(context);
                          },
                          type: ButtonType.secondary,
                          icon: const Icon(Icons.qr_code),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxxl),
            
            // Action buttons
            CustomButton(
              text: 'Create New Build',
              onPressed: () {
                context.go('/build-configuration');
              },
              type: ButtonType.primary,
              size: ButtonSize.large,
              isFullWidth: true,
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            CustomButton(
              text: 'Back to Dashboard',
              onPressed: () {
                context.go('/dashboard');
              },
              type: ButtonType.ghost,
              isFullWidth: true,
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          
          const SizedBox(height: AppSpacing.sm),
          
          Text(
            value,
            style: AppTypography.subtitle1.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: AppSpacing.xs),
          
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformResult(BuildContext context, BuildResult result) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          // Platform header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  result.icon,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: AppSpacing.lg),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.platform,
                      style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
                    ),
                    
                    const SizedBox(height: AppSpacing.xs),
                    
                    Text(
                      '${result.fileSize} • ${result.buildTime}',
                      style: AppTypography.caption.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              
              StatusBadge(
                text: 'Ready',
                color: AppColors.success,
                icon: Icons.check_circle,
              ),
            ],
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // QR Code
          if (result.platform != 'Web')
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              ),
              child: Column(
                children: [
                  Text(
                    'Scan to Download',
                    style: AppTypography.caption.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    color: Colors.white,
                    child: QrImageView(
                      data: result.qrCode,
                      version: QrVersions.auto,
                      size: 120.0,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Download buttons
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: result.platform == 'Web' ? 'Play Now' : 'Download',
                  onPressed: () {
                    _launchDownload(context, result.downloadUrl);
                  },
                  type: ButtonType.primary,
                  icon: Icon(result.platform == 'Web' ? Icons.play_arrow : Icons.download),
                ),
              ),
              
              if (result.platform != 'Web') ...[
                const SizedBox(width: AppSpacing.lg),
                
                CustomButton(
                  text: 'Copy Link',
                  onPressed: () {
                    _copyToClipboard(context, result.downloadUrl);
                  },
                  type: ButtonType.secondary,
                  icon: const Icon(Icons.link),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _shareGameLink(BuildContext context) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share link copied to clipboard!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _copyQRCode(BuildContext context) {
    // TODO: Implement QR code copy functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR code saved to gallery!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _launchDownload(BuildContext context, String url) {
    // TODO: Implement URL launcher
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading from: $url'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    // TODO: Implement clipboard functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard!'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}

class BuildResult {
  final String platform;
  final BuildStatus status;
  final String fileSize;
  final String downloadUrl;
  final String qrCode;
  final String buildTime;
  final IconData icon;

  const BuildResult({
    required this.platform,
    required this.status,
    required this.fileSize,
    required this.downloadUrl,
    required this.qrCode,
    required this.buildTime,
    required this.icon,
  });
}

enum BuildStatus {
  completed,
  failed,
  cancelled,
}
