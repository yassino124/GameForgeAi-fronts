import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../presentation/widgets/widgets.dart';

class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          'Space Adventure',
          style: AppTypography.subtitle1,
        ),
        leading: IconButton(
          onPressed: () => context.go('/dashboard'),
          icon: Icon(
            Icons.arrow_back,
            color: cs.onSurface,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Edit project
            },
            icon: Icon(
              Icons.edit,
              color: cs.onSurface,
            ),
          ),
          IconButton(
            onPressed: () {
              // TODO: Share project
            },
            icon: Icon(
              Icons.share,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
      
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image/preview
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                gradient: AppColors.primaryGradient,
                boxShadow: AppShadows.boxShadowLarge,
              ),
              child: Stack(
                children: [
                  // Game preview placeholder
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.onPrimary.withOpacity(0.12),
                      ),
                      child: Icon(
                        Icons.games,
                        size: 50,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                  
                  // Play button overlay
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: CustomButton(
                      text: 'Play',
                      onPressed: () {
                        // TODO: Launch game
                      },
                      type: ButtonType.primary,
                      size: ButtonSize.small,
                      icon: const Icon(Icons.play_arrow),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            
            // Project info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Space Adventure',
                        style: AppTypography.h2,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'A thrilling space exploration game',
                        style: AppTypography.body1.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                  ),
                  child: Text(
                    'Completed',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            
            // Stats grid
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Downloads',
                    '1,234',
                    Icons.download,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Rating',
                    '4.8',
                    Icons.star,
                    AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Plays',
                    '5.6K',
                    Icons.play_arrow,
                    AppColors.success,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            
            // Description
            Text(
              'Description',
              style: AppTypography.subtitle1,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Embark on an epic journey through the cosmos in Space Adventure. Explore distant planets, discover alien civilizations, and uncover the mysteries of the universe. With stunning graphics and immersive gameplay, this space exploration game will keep you engaged for hours.',
              style: AppTypography.body1.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            
            // Features
            Text(
              'Features',
              style: AppTypography.subtitle1,
            ),
            const SizedBox(height: AppSpacing.lg),
            Column(
              children: [
                _buildFeatureItem('🚀 Multiple spacecraft to choose from'),
                _buildFeatureItem('🌍 Explore procedurally generated planets'),
                _buildFeatureItem('👽 Meet alien species and trade resources'),
                _buildFeatureItem('⚔️ Engage in space combat'),
                _buildFeatureItem('🏗️ Build your own space station'),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            
            // Screenshots
            Text(
              'Screenshots',
              style: AppTypography.subtitle1,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                itemBuilder: (context, index) {
                  return Container(
                    width: 300,
                    margin: const EdgeInsets.only(right: AppSpacing.lg),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      color: cs.surface,
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image,
                            size: 48,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Screenshot ${index + 1}',
                            style: AppTypography.body2.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Edit Project',
                    onPressed: () {
                      // TODO: Edit project
                    },
                    type: ButtonType.secondary,
                    icon: const Icon(Icons.edit),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: CustomButton(
                    text: 'Build Game',
                    onPressed: () {
                      context.go('/build-configuration');
                    },
                    type: ButtonType.primary,
                    icon: const Icon(Icons.build),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xxl),
          ],
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
            color: color,
            size: 24,
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

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body2,
            ),
          ),
        ],
      ),
    );
  }
}
