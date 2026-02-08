import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget section({required String title, required String body}) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
        ),
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
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant, height: 1.35),
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
          'Privacy Policy',
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
            section(
              title: 'Overview',
              body: 'This screen is a simplified privacy overview for the demo build. Replace with your official privacy policy before production.',
            ),
            section(
              title: 'Data we collect',
              body: 'Account data (email, username) and usage events needed to provide core features. Payment details are handled by Stripe and are not stored by the app.',
            ),
            section(
              title: 'How we use data',
              body: 'To authenticate, personalize your experience, and improve generation quality and performance.',
            ),
            section(
              title: 'Your choices',
              body: 'You can update your profile, change password, and sign out at any time. For account deletion requests, use the Delete Account option.',
            ),
            Text(
              'Last updated: 2024-01-01',
              style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
