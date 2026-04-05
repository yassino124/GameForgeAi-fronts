import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../widgets/widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  bool _isLoading = false;
  String? _error;
  bool _animateIn = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _animateIn = true);
      }
    });
  }

  Widget _buildEntrance({
    required Widget child,
    required int order,
    Offset beginOffset = const Offset(0, 0.08),
  }) {
    final duration = Duration(milliseconds: 320 + (order * 120));

    return AnimatedOpacity(
      opacity: _animateIn ? 1 : 0,
      duration: duration,
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _animateIn ? Offset.zero : beginOffset,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    Map<String, dynamic> res;
    try {
      res = await AuthService.forgotPassword(_emailController.text.trim());
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
      _error = res['message']?.toString() ?? 'Failed to send reset instructions';
    });
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(v)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
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
          'Forgot Password',
          style: AppTypography.subtitle1.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.authBackgroundGradient(context),
        ),
        child: Stack(
          children: [
            const AuthBackdropGlow(),
            SafeArea(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: AppSpacing.paddingHorizontalLarge,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: AppSpacing.xxxl),

                        _buildEntrance(
                          order: 0,
                          beginOffset: const Offset(0, -0.08),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha: 0.12),
                              boxShadow: AppShadows.boxShadowPrimaryGlow,
                            ),
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              size: 44,
                              color: AppColors.primary,
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        _buildEntrance(
                          order: 1,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: AppColors.primary.withValues(alpha: 0.14),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.shield_outlined,
                                        size: 15, color: AppColors.primary),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      'Secure recovery',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Reset your password',
                                  style: AppTypography.h3,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Enter your email and we will send you a reset link.',
                                  style: AppTypography.body1.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        _buildEntrance(
                          order: 2,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.white.withValues(alpha: 0.82),
                              border: Border.all(color: AppColors.border.withValues(alpha: 0.35)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    gradient: const LinearGradient(
                                      colors: [AppColors.primary, AppColors.secondary],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'Account recovery email',
                                  style: AppTypography.body3.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
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
                                if (_error != null) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    _error!,
                                    style: AppTypography.body2.copyWith(color: cs.error),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.xl),
                                CustomButton(
                                  text: 'Send reset link',
                                  onPressed: _submit,
                                  isLoading: _isLoading,
                                  isFullWidth: true,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
