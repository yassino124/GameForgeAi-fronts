import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
          'Terms of Service',
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
              body: 'These terms are a placeholder for the demo build. Replace with official legal text before production.',
            ),
            section(
              title: 'Acceptable use',
              body: 'You agree not to misuse the service, attempt to access restricted areas, or violate applicable laws.',
            ),
            section(
              title: 'Subscriptions',
              body: 'Paid subscriptions renew automatically unless cancelled. Prices and availability may change.',
            ),
            section(
              title: 'Disclaimer',
              body: 'The service is provided as-is. Availability and features may change.',
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
