import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../widgets/widgets.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _agreeToTerms = false;
  String _selectedRole = 'user'; // Default role
  bool _animateIn = false;
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  Future<void> _signInWithBiometrics() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final ok = await authProvider.tryBiometricLogin();
    if (!mounted) return;

    if (ok) {
      context.go('/dashboard');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(authProvider.errorMessage ?? 'Biometric login failed'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  static const List<Map<String, String>> _roles = [
    {'value': 'user', 'label': 'User', 'description': 'Create and play games'},
    {'value': 'devl', 'label': 'Developer', 'description': 'Advanced features and APIs'},
  ];

  String _safeRole(String? role) {
    final r = (role ?? '').trim().toLowerCase();
    if (r == 'devl') return 'devl';
    return 'user';
  }

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = _openTermsSheet;
    _privacyRecognizer = TapGestureRecognizer()..onTap = _openTermsSheet;
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
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _openTermsSheet() async {
    FocusScope.of(context).unfocus();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.86,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                color: cs.surface,
                border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        Icon(Icons.description_rounded, color: cs.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Terms & Protocols',
                          style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      children: [
                        _buildTermsSection(
                          '01. Platform Access',
                          'By accessing GameForge AI Studio, you enter an ecosystem of high-end game development tools. You agree to use these tools for legitimate creative purposes and respect our ethical AI guidelines.',
                        ),
                        _buildTermsSection(
                          '02. Intellectual Property',
                          'Games generated through our AI remain your creative property. However, the proprietary algorithms, models, and platform architecture are the exclusive property of GameForge AI.',
                        ),
                        _buildTermsSection(
                          '03. Usage Limits',
                          'Accounts are intended for individual or professional team use. Automated scraping or reverse engineering of our AI generation pipeline is strictly prohibited.',
                        ),
                        _buildTermsSection(
                          '04. Privacy & Data',
                          'We process your prompts and data to improve your game generation experience. We never sell your personal data to third parties. Your projects are encrypted.',
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              text: 'Close',
                              type: ButtonType.secondary,
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CustomButton(
                              text: 'Accept Protocols',
                              onPressed: () {
                                setState(() => _agreeToTerms = true);
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTermsSection(String title, String content) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: AppTypography.body2.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: kToolbarHeight + AppSpacing.sm,
        title: Text(
          'Create Account',
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
                  child: AutofillGroup(
                    child: Column(
                      children: [
                    const SizedBox(height: AppSpacing.xl),

                    _buildEntrance(
                      order: 0,
                      beginOffset: const Offset(0, -0.08),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.12),
                          boxShadow: AppShadows.boxShadowPrimaryGlow,
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 42,
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
                              color: AppColors.secondary.withValues(alpha: 0.14),
                              border: Border.all(
                                color: AppColors.secondary.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome_rounded,
                                    size: 15, color: AppColors.secondary),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  'Let\'s build something epic',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Create Account',
                            style: AppTypography.h2,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Join the AI game creation revolution',
                            style: AppTypography.body1.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                
                    const SizedBox(height: AppSpacing.xxxl),
                
                    // Sign up form
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                          Container(
                            width: double.infinity,
                            height: 5,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: const LinearGradient(
                                colors: [AppColors.secondary, AppColors.primary],
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Set up your profile and start creating',
                              style: AppTypography.body3.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Full name field
                          CustomTextField(
                            label: 'Full Name',
                            hint: 'Enter your full name',
                            prefixIcon: Icons.person,
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your full name';
                              }
                              if (value.length < 2) {
                                return 'Name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: AppSpacing.lg),
                          
                          // Email field
                          CustomTextField(
                            label: 'Email',
                            hint: 'Enter your email',
                            prefixIcon: Icons.email,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: AppSpacing.lg),
                          
                          // Password field
                          CustomPasswordField(
                            label: 'Password',
                            hint: 'Create a strong password',
                            controller: _passwordController,
                            autofillHints: const [AutofillHints.newPassword],
                            showStrengthIndicator: true,
                            onChanged: (value) {
                              // Trigger validation when password changes
                              if (_confirmPasswordController.text.isNotEmpty) {
                                _formKey.currentState?.validate();
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              if (!value.contains(RegExp(r'[A-Z]'))) {
                                return 'Password must contain at least one uppercase letter';
                              }
                              if (!value.contains(RegExp(r'[a-z]'))) {
                                return 'Password must contain at least one lowercase letter';
                              }
                              if (!value.contains(RegExp(r'[0-9]'))) {
                                return 'Password must contain at least one number';
                              }
                              if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
                                return 'Password must contain at least one special character';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: AppSpacing.lg),
                          
                          // Confirm password field
                          CustomTextField(
                            label: 'Confirm Password',
                            hint: 'Re-enter your password',
                            prefixIcon: Icons.lock_outline,
                            obscureText: true,
                            controller: _confirmPasswordController,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                            onSubmitted: (_) => _signUp(),
                          ),
                          
                          const SizedBox(height: AppSpacing.lg),
                          
                          // Role selection
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Your Role',
                                style: AppTypography.body1.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ..._roles.map((role) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                                  onTap: () {
                                    setState(() {
                                      _selectedRole = role['value']!;
                                    });
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                                      border: Border.all(
                                        color: _selectedRole == role['value']
                                            ? AppColors.primary
                                            : AppColors.border,
                                        width: _selectedRole == role['value'] ? 2 : 1,
                                      ),
                                      color: _selectedRole == role['value']
                      ? AppColors.primary.withValues(alpha: 0.1)
                                          : Colors.transparent,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _selectedRole == role['value']
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_unchecked,
                                          color: _selectedRole == role['value']
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                role['label']!,
                                                style: AppTypography.body2.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: _selectedRole == role['value']
                                                      ? AppColors.primary
                                                      : AppColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                role['description']!,
                                                style: AppTypography.caption.copyWith(
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )),
                            ],
                          ),
                          
                          const SizedBox(height: AppSpacing.lg),
                          
                          // Remember me checkbox
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              return Row(
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                                    onTap: () {
                                      authProvider.setRememberMe(!authProvider.rememberMe);
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: authProvider.rememberMe,
                                          onChanged: (value) {
                                            authProvider.setRememberMe(value ?? false);
                                          },
                                          activeColor: AppColors.primary,
                                        ),
                                        Text(
                                          'Remember me',
                                          style: AppTypography.body2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          
                          const SizedBox(height: AppSpacing.lg),
                          
                          // Terms and conditions
                          Row(
                            children: [
                              Checkbox(
                                value: _agreeToTerms,
                                onChanged: (value) {
                                  setState(() {
                                    _agreeToTerms = value ?? false;
                                  });
                                },
                                activeColor: AppColors.primary,
                              ),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    text: 'I agree to the ',
                                    style: AppTypography.body2,
                                    children: [
                                      TextSpan(
                                        text: 'Terms & Conditions',
                                        recognizer: _termsRecognizer,
                                        style: AppTypography.body2.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      const TextSpan(text: ' and '),
                                      TextSpan(
                                        text: 'Privacy Policy',
                                        recognizer: _privacyRecognizer,
                                        style: AppTypography.body2.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: AppSpacing.xxl),
                          
                          // Create account button
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              return _buildEntrance(
                                order: 3,
                                beginOffset: const Offset(0, 0.05),
                                child: CustomButton(
                                  text: 'Create Account',
                                  onPressed: _signUp,
                                  isLoading: authProvider.isLoading,
                                  isFullWidth: true,
                                ),
                              );
                            },
                          ),
                          
                          const SizedBox(height: AppSpacing.xl),

                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              return _buildEntrance(
                                order: 4,
                                beginOffset: const Offset(0, 0.06),
                                child: CustomButton(
                                  text: 'Continue with Google',
                                  onPressed: () => _signUpWithGoogle(),
                                  type: ButtonType.secondary,
                                  isLoading: authProvider.isLoading,
                                  isFullWidth: true,
                                  icon: const Icon(
                                    FontAwesomeIcons.google,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: AppSpacing.md),

                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              return FutureBuilder<bool>(
                                future: authProvider.hasBiometricLoginConfigured(),
                                builder: (context, snapshot) {
                                  final show = snapshot.data == true;
                                  if (!show) return const SizedBox.shrink();

                                  return _buildEntrance(
                                    order: 5,
                                    beginOffset: const Offset(0, 0.07),
                                    child: CustomButton(
                                      text: 'Continue with Face ID / Touch ID',
                                      onPressed: _signInWithBiometrics,
                                      type: ButtonType.secondary,
                                      isLoading: authProvider.isLoading,
                                      isFullWidth: true,
                                      icon: const Icon(
                                        Icons.fingerprint,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),

                          const SizedBox(height: AppSpacing.xl),
                          
                          // Sign in link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: AppTypography.body2.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  context.go('/signin');
                                },
                                child: Text(
                                  'Sign In',
                                  style: AppTypography.body2.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: AppSpacing.xxl),
                            ],
                          ),
                        ),
                      ),
                    ),
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

  Future<void> _signUp() async {
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms & Conditions'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      try {
        final safeRole = _safeRole(_selectedRole);
        final success = await authProvider.register(
          username: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: safeRole,
          rememberMe: authProvider.rememberMe,
        );

        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Registration successful! Check your email to verify your account.'),
                backgroundColor: AppColors.success,
              ),
            );
            final encodedEmail = Uri.encodeComponent(_emailController.text.trim());
            context.go('/email-verification?email=$encodedEmail');
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authProvider.errorMessage ?? 'Registration failed'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unexpected error: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _signUpWithGoogle() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final safeRole = _safeRole(_selectedRole);
      final success = await authProvider.loginWithGoogle(
        rememberMe: authProvider.rememberMe,
        role: safeRole,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google login successful!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/dashboard');
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Google login failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
