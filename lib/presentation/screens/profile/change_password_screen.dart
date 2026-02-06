import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../widgets/widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateCurrentPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please enter your current password';
    return null;
  }

  String? _validateNewPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please enter a new password';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please confirm your new password';
    if (v != _newPasswordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit(AuthProvider authProvider) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final ok = await authProvider.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;

    if (ok) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated'),
          backgroundColor: AppColors.success,
        ),
      );

      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/settings');
      }
      return;
    }

    setState(() {
      _isLoading = false;
      _error = authProvider.errorMessage ?? 'Failed to update password';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: cs.surface,
            elevation: 0,
            toolbarHeight: kToolbarHeight + AppSpacing.sm,
            leading: IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/settings');
                }
              },
              icon: Icon(Icons.arrow_back, color: cs.onSurface),
            ),
            title: Text(
              'Change Password',
              style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bottomInset = MediaQuery.of(context).viewInsets.bottom;

                  return SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      left: AppSpacing.lg,
                      right: AppSpacing.lg,
                      bottom: AppSpacing.lg + bottomInset,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.xxl),
                            Text(
                              'Update your password',
                              style: AppTypography.h3,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Enter your current password and choose a new one.',
                              style: AppTypography.body1.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            CustomTextField(
                              label: 'Current password',
                              hint: 'Enter current password',
                              prefixIcon: Icons.lock_outline,
                              obscureText: true,
                              controller: _currentPasswordController,
                              textInputAction: TextInputAction.next,
                              validator: _validateCurrentPassword,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            CustomTextField(
                              label: 'New password',
                              hint: 'Enter new password',
                              prefixIcon: Icons.lock,
                              obscureText: true,
                              controller: _newPasswordController,
                              textInputAction: TextInputAction.next,
                              validator: _validateNewPassword,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            CustomTextField(
                              label: 'Confirm new password',
                              hint: 'Confirm new password',
                              prefixIcon: Icons.lock,
                              obscureText: true,
                              controller: _confirmPasswordController,
                              textInputAction: TextInputAction.done,
                              validator: _validateConfirmPassword,
                              enabled: !_isLoading,
                              onSubmitted: (_) => _submit(authProvider),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                _error!,
                                style: AppTypography.body2.copyWith(color: cs.error),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xl),
                            CustomButton(
                              text: 'Update password',
                              onPressed: _isLoading ? null : () => _submit(authProvider),
                              isLoading: _isLoading,
                              isFullWidth: true,
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
