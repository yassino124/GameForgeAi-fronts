import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget tile({
      required IconData icon,
      required String title,
      required String subtitle,
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
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                gradient: AppColors.secondaryGradient,
                boxShadow: AppShadows.boxShadowSmall,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.subtitle2.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
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
          'About',
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
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: AppColors.primaryGradient,
                      boxShadow: AppShadows.boxShadowSmall,
                    ),
                    child: const Icon(Icons.games, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GameForge AI',
                          style: AppTypography.h3.copyWith(color: cs.onSurface),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Version 1.0.0',
                          style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            tile(
              icon: Icons.auto_awesome,
              title: 'What it does',
              subtitle: 'Generate game concepts, assets, and build configurations using AI.',
            ),
            tile(
              icon: Icons.lock_outline,
              title: 'Security',
              subtitle: 'We use modern authentication and keep sensitive data protected.',
            ),
            tile(
              icon: Icons.credit_card,
              title: 'Payments',
              subtitle: 'Subscriptions are managed securely through Stripe.',
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '© 2024 GameForge AI. All rights reserved.',
              style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
