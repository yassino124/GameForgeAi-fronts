import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';

class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget step({
      required int index,
      required String title,
      required String description,
      required IconData icon,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                gradient: AppColors.primaryGradient,
                boxShadow: AppShadows.boxShadowSmall,
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: AppTypography.subtitle2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: cs.primary, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.subtitle2.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    description,
                    style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'How to use',
          style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.backgroundGradient : AppTheme.backgroundGradientLight,
        ),
        child: ListView(
          padding: AppSpacing.paddingLarge,
          children: [
            Text(
              'Build games faster with AI',
              style: AppTypography.h3.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Follow these steps to create, generate, and export your game.',
              style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            step(
              index: 1,
              title: 'Choose a template',
              description: 'Pick a base template that matches your game idea.',
              icon: Icons.dashboard_customize_outlined,
            ),
            step(
              index: 2,
              title: 'Configure AI generation',
              description: 'Describe your game, style, and features. GameForge AI will generate assets and structure.',
              icon: Icons.auto_awesome,
            ),
            step(
              index: 3,
              title: 'Build & export',
              description: 'Select platforms (iOS/Android/Web), then build and export your project.',
              icon: Icons.build_circle_outlined,
            ),
            step(
              index: 4,
              title: 'Manage subscription',
              description: 'Upgrade anytime to unlock more credits and advanced workflows.',
              icon: Icons.workspace_premium_outlined,
            ),
          ],
        ),
      ),
    );
  }
}
