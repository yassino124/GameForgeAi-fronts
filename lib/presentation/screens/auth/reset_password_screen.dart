import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../widgets/widgets.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? initialTokenOrUrl;
  final String? initialEmail;

  const ResetPasswordScreen({
    super.key,
    this.initialTokenOrUrl,
    this.initialEmail,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _tokenController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _tokenController = TextEditingController(text: widget.initialTokenOrUrl ?? '');
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Please enter your email';
    final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    if (!isValid) return 'Please enter a valid email';
    return null;
  }

  String _extractToken(String input) {
    final v = input.trim();
    if (v.isEmpty) return '';

    final uri = Uri.tryParse(v);
    if (uri != null && uri.hasScheme && uri.hasAuthority) {
      final tokenFromQuery = uri.queryParameters['token'];
      if (tokenFromQuery != null && tokenFromQuery.trim().isNotEmpty) {
        return tokenFromQuery.trim();
      }
      if (uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.last.trim();
      }
    }

    if (v.contains('token=')) {
      final asUri = Uri.tryParse(v);
      final tokenFromQuery = asUri?.queryParameters['token'];
      if (tokenFromQuery != null && tokenFromQuery.trim().isNotEmpty) {
        return tokenFromQuery.trim();
      }
    }

    return v;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final rawTokenOrUrl = _tokenController.text.trim();
    final hasTokenOrUrl = rawTokenOrUrl.isNotEmpty;

    if (!hasTokenOrUrl) {
      Map<String, dynamic> res;

      try {
        res = await AuthService.forgotPassword(_emailController.text);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
        return;
      }

      if (!mounted) return;

      if (res['success'] == true) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset link sent. Check your email.'),
            backgroundColor: AppColors.success,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = false;
        _error = res['message']?.toString() ?? 'Failed to send reset link';
      });
      return;
    }

    final token = _extractToken(_tokenController.text);
    Map<String, dynamic> res;

    try {
      res = await AuthService.resetPassword(
        token: token,
        newPassword: _passwordController.text,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      return;
    }

    if (!mounted) return;

    if (res['success'] == true) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated. You can sign in now.'),
          backgroundColor: AppColors.success,
        ),
      );

      context.go('/signin');
      return;
    }

    setState(() {
      _isLoading = false;
      _error = res['message']?.toString() ?? 'Failed to reset password';
    });
  }

  String? _validateToken(String? value) {
    final token = _extractToken(value ?? '');
    if (token.isEmpty) return 'Please enter the token (or paste the reset link)';
    if (token.length < 10) return 'Token looks too short';
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please enter a new password';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please confirm your new password';
    if (v != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final emailHint = (_emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : (widget.initialEmail ?? '').trim())
        .trim();

    final rawTokenOrUrl = _tokenController.text.trim();
    final hasTokenOrUrl = rawTokenOrUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: kToolbarHeight + AppSpacing.sm,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/signin');
            }
          },
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
        ),
        title: Text(
          'Reset Password',
          style: AppTypography.subtitle1.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundGradient
              : AppTheme.backgroundGradientLight,
        ),
        child: SafeArea(
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
                          const SizedBox(height: AppSpacing.xxxl),
                          Text(
                            hasTokenOrUrl ? 'Create a new password' : 'Reset your password',
                            style: AppTypography.h3,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            hasTokenOrUrl
                                ? (emailHint.isNotEmpty
                                    ? 'Resetting password for $emailHint'
                                    : 'Set your new password below.')
                                : 'Enter your email and we will send you a reset link.',
                            style: AppTypography.body1.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          if (!hasTokenOrUrl) ...[
                            CustomTextField(
                              label: 'Email',
                              hint: 'Enter your email',
                              prefixIcon: Icons.email,
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              validator: _validateEmail,
                              onSubmitted: (_) => _submit(),
                            ),
                          ] else ...[
                            CustomTextField(
                              label: 'New password',
                              hint: 'Enter new password',
                              prefixIcon: Icons.lock,
                              obscureText: true,
                              controller: _passwordController,
                              textInputAction: TextInputAction.next,
                              validator: _validatePassword,
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
                              onSubmitted: (_) => _submit(),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _error!,
                              style: AppTypography.body2.copyWith(color: cs.error),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          CustomButton(
                            text: hasTokenOrUrl ? 'Reset password' : 'Send reset link',
                            onPressed: _submit,
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
      ),
    );
  }
}
