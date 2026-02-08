import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';

class SecurityCenterScreen extends StatelessWidget {
  const SecurityCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget card({
      required IconData icon,
      required String title,
      required String subtitle,
      VoidCallback? onTap,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              gradient: AppColors.primaryGradient,
              boxShadow: AppShadows.boxShadowSmall,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          title: Text(
            title,
            style: AppTypography.body2.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
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
          'Security',
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
              'Security Center',
              style: AppTypography.h3.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Manage password, biometrics, and best practices to keep your account safe.',
              style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            card(
              icon: Icons.lock_outline,
              title: 'Change password',
              subtitle: 'Update your password regularly.',
              onTap: () => context.push('/change-password'),
            ),
            card(
              icon: Icons.fingerprint,
              title: 'Biometric login',
              subtitle: 'Enable Face ID / Touch ID from Settings > Security.',
            ),
            card(
              icon: Icons.phishing_outlined,
              title: 'Avoid phishing',
              subtitle: 'Never share your password. Verify links before clicking.',
            ),
            card(
              icon: Icons.shield_outlined,
              title: 'Device security',
              subtitle: 'Enable device passcode and keep iOS updated.',
            ),
          ],
        ),
      ),
    );
  }
}
