import 'package:flutter/material.dart';
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
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundGradient
              : AppTheme.backgroundGradientLight,
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: AppSpacing.paddingHorizontalLarge,
              child: AutofillGroup(
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    
                    // Header
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
                
                    const SizedBox(height: AppSpacing.xxxl),
                
                    // Sign up form
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
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
                                          ? AppColors.primary.withOpacity(0.1)
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
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _agreeToTerms = !_agreeToTerms;
                                    });
                                  },
                                  child: Text.rich(
                                    TextSpan(
                                      text: 'I agree to the ',
                                      style: AppTypography.body2,
                                      children: [
                                        TextSpan(
                                          text: 'Terms & Conditions',
                                          style: AppTypography.body2.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const TextSpan(text: ' and '),
                                        TextSpan(
                                          text: 'Privacy Policy',
                                          style: AppTypography.body2.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: AppSpacing.xxl),
                          
                          // Create account button
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              return CustomButton(
                                text: 'Create Account',
                                onPressed: _signUp,
                                isLoading: authProvider.isLoading,
                                isFullWidth: true,
                              );
                            },
                          ),
                          
                          const SizedBox(height: AppSpacing.xl),

                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              return CustomButton(
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

                                  return CustomButton(
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
                  ],
                ),
              ),
            ),
          ),
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
                content: Text('Registration successful!'),
                backgroundColor: AppColors.success,
              ),
            );
            context.go('/dashboard');
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
