import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../widgets/widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        toolbarHeight: kToolbarHeight + AppSpacing.sm,
        leading: Container(
          margin: const EdgeInsets.only(left: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
            ),
          ),
          child: IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 20,
            ),
          ),
        ),
        title: Text(
          'Settings',
          style: AppTypography.subtitle1.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.backgroundGradient : AppTheme.backgroundGradientLight,
        ),
        child: ListView(
          padding: AppSpacing.paddingLarge,
          children: [
            const SizedBox(height: AppSpacing.sm),

            _ThemeModeCard(isDark: isDark),

            const SizedBox(height: AppSpacing.xl),

            _buildSettingsSection(
              context,
              'Account Settings',
              [
                _buildSettingsItem(
                  context,
                  'Edit Profile',
                  'Update your personal information',
                  Icons.person,
                  () => _navigateToEditProfile(context),
                ),
                _buildSettingsItem(
                  context,
                  'Change Password',
                  'Update your password',
                  Icons.lock,
                  () => _navigateToChangePassword(context),
                ),
                _buildSettingsItem(
                  context,
                  'Email Preferences',
                  'Manage email notifications',
                  Icons.email,
                  () => _navigateToEmailPreferences(context),
                ),
              ],
            ),
          
          const SizedBox(height: AppSpacing.xl),
          
            _buildSettingsSection(
              context,
              'Security',
              [
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    final cs = Theme.of(context).colorScheme;
                    final isEnabled = authProvider.biometricEnabled;

                    return SwitchListTile(
                      secondary: Icon(
                        Icons.fingerprint,
                        color: cs.primary,
                      ),
                      title: Text(
                        'Login with Face ID / Touch ID',
                        style: AppTypography.body2.copyWith(color: cs.onSurface),
                      ),
                      subtitle: Text(
                        'Use biometrics to sign in without a password',
                        style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                      ),
                      value: isEnabled,
                      onChanged: authProvider.isLoading
                          ? null
                          : (value) async {
                              final ok = await authProvider.setBiometricEnabled(value);
                              if (!context.mounted) return;
                              if (!ok && authProvider.errorMessage != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(authProvider.errorMessage!)),
                                );
                              }
                            },
                    );
                  },
                ),
              ],
            ),
          
          const SizedBox(height: AppSpacing.xl),
          
            _buildSettingsSection(
              context,
              'Subscription',
              [
                _buildSettingsItem(
                  context,
                  'Current Plan',
                  'Pro Plan - \$9.99/month',
                  Icons.workspace_premium,
                  () => _navigateToSubscription(context),
                ),
                _buildSettingsItem(
                  context,
                  'Payment Methods',
                  'Manage payment options',
                  Icons.payment,
                  () => _navigateToPaymentMethods(context),
                ),
                _buildSettingsItem(
                  context,
                  'Billing History',
                  'View past invoices',
                  Icons.receipt,
                  () => _navigateToBillingHistory(context),
                ),
              ],
            ),
          
          const SizedBox(height: AppSpacing.xl),
          
            _buildSettingsSection(
              context,
              'App Settings',
              [
                _buildSettingsItem(
                  context,
                  'Notifications',
                  'Push and in-app notifications',
                  Icons.notifications,
                  () => _navigateToNotifications(context),
                ),
                _buildSettingsItem(
                  context,
                  'Privacy & Security',
                  'Data privacy and security settings',
                  Icons.security,
                  () => _navigateToPrivacy(context),
                ),
                _buildSettingsItem(
                  context,
                  'Appearance',
                  'Theme and display settings',
                  Icons.palette,
                  () => _navigateToAppearance(context),
                ),
                _buildSettingsItem(
                  context,
                  'Storage',
                  'Manage app storage and cache',
                  Icons.storage,
                  () => _navigateToStorage(context),
                ),
              ],
            ),
          
          const SizedBox(height: AppSpacing.xl),
          
            _buildSettingsSection(
              context,
              'Support',
              [
                _buildSettingsItem(
                  context,
                  'Help Center',
                  'Get help and support',
                  Icons.help,
                  () => _navigateToHelp(context),
                ),
                _buildSettingsItem(
                  context,
                  'Contact Support',
                  'Reach out to our team',
                  Icons.support_agent,
                  () => _navigateToContactSupport(context),
                ),
                _buildSettingsItem(
                  context,
                  'Report a Bug',
                  'Report issues and feedback',
                  Icons.bug_report,
                  () => _navigateToReportBug(context),
                ),
              ],
            ),
          
          const SizedBox(height: AppSpacing.xl),
          
            _buildSettingsSection(
              context,
              'About',
              [
                _buildSettingsItem(
                  context,
                  'About GameForge AI',
                  'App version and information',
                  Icons.info,
                  () => _showAboutDialog(context),
                ),
                _buildSettingsItem(
                  context,
                  'Terms of Service',
                  'Read our terms and conditions',
                  Icons.description,
                  () => _navigateToTerms(context),
                ),
                _buildSettingsItem(
                  context,
                  'Privacy Policy',
                  'Read our privacy policy',
                  Icons.privacy_tip,
                  () => _navigateToPrivacyPolicy(context),
                ),
              ],
            ),
          
          const SizedBox(height: AppSpacing.xl),
          
            _buildSettingsSection(
              context,
              'Danger Zone',
              [
                _buildSettingsItem(
                  context,
                  'Delete Account',
                  'Permanently delete your account',
                  Icons.delete_forever,
                  () => _showDeleteAccountDialog(context),
                  isDestructive: true,
                ),
              ],
            ),
          
          const SizedBox(height: AppSpacing.xl),
          
            CustomButton(
              text: 'Sign Out',
              onPressed: () => _showSignOutDialog(context),
              type: ButtonType.danger,
              isFullWidth: true,
            ),
            
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, String title, List<Widget> items) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              title,
              style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
            ),
          ),
          
          ...items,
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.error : cs.primary,
      ),
      title: Text(
        title,
        style: AppTypography.body2.copyWith(
          color: isDestructive ? AppColors.error : cs.onSurface,
        ),
      ),
      subtitle: Text(
        description,
        style: AppTypography.caption.copyWith(
          color: cs.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: cs.onSurfaceVariant,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  void _navigateToEditProfile(BuildContext context) {
    context.push('/edit-profile');
  }

  void _navigateToChangePassword(BuildContext context) {
    context.push('/change-password');
  }

  void _navigateToEmailPreferences(BuildContext context) {
    // TODO: Navigate to email preferences
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email Preferences - Coming Soon')),
    );
  }

  void _navigateToSubscription(BuildContext context) {
    context.push('/subscription');
  }

  void _navigateToPaymentMethods(BuildContext context) {
    // TODO: Navigate to payment methods
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment Methods - Coming Soon')),
    );
  }

  void _navigateToBillingHistory(BuildContext context) {
    // TODO: Navigate to billing history
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Billing History - Coming Soon')),
    );
  }

  void _navigateToNotifications(BuildContext context) {
    context.go('/notifications');
  }

  void _navigateToPrivacy(BuildContext context) {
    // TODO: Navigate to privacy settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy Settings - Coming Soon')),
    );
  }

  void _navigateToAppearance(BuildContext context) {
    // TODO: Navigate to appearance settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Appearance Settings - Coming Soon')),
    );
  }

  void _navigateToStorage(BuildContext context) {
    // TODO: Navigate to storage settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Storage Settings - Coming Soon')),
    );
  }

  void _navigateToHelp(BuildContext context) {
    // TODO: Navigate to help center
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Help Center - Coming Soon')),
    );
  }

  void _navigateToContactSupport(BuildContext context) {
    // TODO: Navigate to contact support
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact Support - Coming Soon')),
    );
  }

  void _navigateToReportBug(BuildContext context) {
    // TODO: Navigate to report bug
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report Bug - Coming Soon')),
    );
  }

  void _navigateToTerms(BuildContext context) {
    // TODO: Navigate to terms of service
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terms of Service - Coming Soon')),
    );
  }

  void _navigateToPrivacyPolicy(BuildContext context) {
    // TODO: Navigate to privacy policy
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy Policy - Coming Soon')),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'GameForge AI',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.games,
        size: 48,
        color: AppColors.primary,
      ),
      children: [
        const Text(
          'GameForge AI is a revolutionary platform that uses artificial intelligence to help you create amazing games.',
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          '© 2024 GameForge AI. All rights reserved.',
        ),
      ],
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement account deletion
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion - Coming Soon'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/signin');
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeCard extends StatelessWidget {
  final bool isDark;

  const _ThemeModeCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final dark = themeProvider.isDark;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            gradient: LinearGradient(
              colors: [
                cs.surface,
                cs.surfaceVariant,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.18 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: dark ? AppColors.primaryGradient : AppColors.secondaryGradient,
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      boxShadow: AppShadows.boxShadowSmall,
                    ),
                    child: Icon(
                      dark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appearance',
                          style: AppTypography.subtitle1.copyWith(color: cs.onSurface),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          dark ? 'Dark mode enabled' : 'Light mode enabled',
                          style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _AnimatedThemeToggle(
                isDark: dark,
                onChanged: (value) {
                  themeProvider.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedThemeToggle extends StatelessWidget {
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _AnimatedThemeToggle({
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => onChanged(!isDark),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
        height: 56,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: cs.surfaceVariant,
          border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 480),
              curve: Curves.easeOutCubic,
              alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 480),
                curve: Curves.easeOutCubic,
                width: 128,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: isDark ? AppColors.primaryGradient : AppColors.secondaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? AppColors.primary : AppColors.secondary).withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _ToggleSide(
                    active: !isDark,
                    label: 'Light',
                    icon: Icons.wb_sunny_rounded,
                  ),
                ),
                Expanded(
                  child: _ToggleSide(
                    active: isDark,
                    label: 'Dark',
                    icon: Icons.nightlight_round,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleSide extends StatelessWidget {
  final bool active;
  final String label;
  final IconData icon;

  const _ToggleSide({
    required this.active,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            duration: const Duration(milliseconds: 480),
            curve: Curves.easeOutBack,
            scale: active ? 1.0 : 0.92,
            child: Icon(
              icon,
              size: 18,
              color: active ? Colors.white : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 480),
            curve: Curves.easeOutCubic,
            style: AppTypography.body2.copyWith(
              color: active ? Colors.white : cs.onSurfaceVariant,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
